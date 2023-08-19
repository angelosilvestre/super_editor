import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_selection.dart';
import 'package:super_editor/src/core/edit_context.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';
import 'package:super_editor/src/infrastructure/platforms/ios/ios_document_controls.dart';
import 'package:super_editor/super_editor.dart';

import 'document_delta_editing.dart';
import 'document_serialization.dart';
import 'ime_decoration.dart';

/// Sends messages to, and receives messages from, the platform Input Method Engine (IME),
/// for the purpose of document editing.

/// A [TextInputClient] that applies IME operations to a [Document].
///
/// Ideally, this class *wouldn't* implement [TextInputConnection], but there are situations
/// where this class needs to care about what's sent to the IME. For more information, see
/// the [setEditingState] override in this class.
class DocumentImeInputClient extends TextInputConnectionDecorator with TextInputClient, DeltaTextInputClient {
  DocumentImeInputClient({
    required this.selection,
    required this.composingRegion,
    required this.textDeltasDocumentEditor,
    required this.imeConnection,
    required this.editContext,
    FloatingCursorController? floatingCursorController,
  }) {
    // Note: we don't listen to document changes because we expect that any change during IME
    // editing will also include a selection change. If we listen to documents and selections, then
    // we'll attempt to serialize the document change before the selection change is made. This
    // results in a new document with an old selection and blows up the serializer. By listening
    // only to selection, we void this race condition.
    selection.addListener(_onContentChange);
    composingRegion.addListener(_onContentChange);
    imeConnection.addListener(_onImeConnectionChange);
    _floatingCursorController = floatingCursorController;

    if (attached) {
      _sendDocumentToIme();
    }
  }

  void dispose() {
    selection.removeListener(_onContentChange);
    composingRegion.removeListener(_onContentChange);
    imeConnection.removeListener(_onImeConnectionChange);
  }

  /// The document's current selection.
  final ValueListenable<DocumentSelection?> selection;

  /// The document's current composing region, which represents a section
  /// of content that the platform IME is thinking about changing, such as spelling
  /// autocorrection.
  final ValueListenable<DocumentRange?> composingRegion;

  final TextDeltasDocumentEditor textDeltasDocumentEditor;

  final ValueListenable<TextInputConnection?> imeConnection;

  /// All resources that are needed to edit a document.
  final SuperEditorContext editContext;

  // TODO: get floating cursor out of here. Use a multi-client IME decorator to split responsibilities
  late FloatingCursorController? _floatingCursorController;

  final Map<String, SelectorHandler> _selectorHandlers = defaultSelectorHandlers;

  void _onContentChange() {
    if (!attached) {
      return;
    }
    if (_isApplyingDeltas) {
      return;
    }

    _sendDocumentToIme();
  }

  void _onImeConnectionChange() {
    client = imeConnection.value;

    if (attached) {
      // This is a new IME connection for us. As far as we're concerned, there is no current
      // IME value.
      _currentTextEditingValue = const TextEditingValue();
      _platformTextEditingValue = const TextEditingValue();

      _sendDocumentToIme();
    }
  }

  /// Override on [TextInputConnection] base class.
  ///
  /// This method is the reason that this class extends [TextInputConnectionDecorator].
  /// Ideally, this object would be exclusively responsible for responding to IME
  /// deltas, and some other object would be exclusively responsible for sending the
  /// document to the IME. However, in certain situations, the decision to send the
  /// document to the IME depends upon knowledge of recent deltas received from the
  /// IME. As a result, this class is not only responsible for applying deltas to
  /// the editor, but also making some decisions about when to send new values to the
  /// IME. This method provides an override to do that, with minimal impact on other
  /// areas of responsibility.
  @override
  void setEditingState(TextEditingValue newValue) {
    if (_isApplyingDeltas) {
      // We're in the middle of applying a series of text deltas. Don't
      // send any updates to the IME because it will conflict with the
      // changes we're actively processing.
      editorImeLog.fine("Ignoring new TextEditingValue because we're applying deltas");
      return;
    }

    editorImeLog.fine("Wants to send a value to IME: $newValue");
    editorImeLog.fine("The current local IME value: $_currentTextEditingValue");
    editorImeLog.fine("The current platform IME value: $_currentTextEditingValue");
    if (newValue != _platformTextEditingValue) {
      // We've been given a new IME value. We compare its value to _platformTextEditingValue
      // instead of _currentTextEditingValue. Why is that?
      //
      // Sometimes the IME reports changes to us, but our document doesn't change
      // in ways that's reflected in the IME.
      //
      // Example: The user has a caret in an empty paragraph. That empty paragraph
      // includes a couple hidden characters, so the IME value might look like:
      //
      //     ". |"
      //
      // The ". " substring is invisible to the user and the "|" represents the caret at
      // the beginning of the empty paragraph.
      //
      // Then the user inserts a newline "\n". This causes Super Editor to insert a new,
      // empty paragraph node, and place the caret in the new, empty paragraph. At this
      // point, we have an issue:
      //
      // This class still sees the TextEditingValue as: ". |"
      //
      // However, the OS IME thinks the TextEditingValue is: ". |\n"
      //
      // In this situation, even though our desired TextEditingValue looks identical to what it
      // was before, it's not identical to what the operating system thinks it is. We need to
      // send our TextEditingValue back to the OS so that the OS doesn't think there's a "\n"
      // sitting in the edit region.
      editorImeLog.fine(
          "Sending forceful update to IME because our local TextEditingValue didn't change, but the IME may have:");
      editorImeLog.fine("$newValue");
      imeConnection.value?.setEditingState(newValue);
    } else {
      editorImeLog.fine("Ignoring new TextEditingValue because it's the same as the existing one: $newValue");
    }

    _currentTextEditingValue = newValue;
    _platformTextEditingValue = newValue;
  }

  @override
  AutofillScope? get currentAutofillScope => throw UnimplementedError();

  @override
  TextEditingValue get currentTextEditingValue => _currentTextEditingValue;
  TextEditingValue _currentTextEditingValue = const TextEditingValue();

  // What the platform IME *thinks* the current value is.
  TextEditingValue _platformTextEditingValue = const TextEditingValue();

  void _updatePlatformImeValueWithDeltas(List<TextEditingDelta> textEditingDeltas) {
    // Apply the deltas to the previous platform-side IME value, to find out
    // what the platform thinks the IME value is, right now.
    for (final delta in textEditingDeltas) {
      _platformTextEditingValue = delta.apply(_platformTextEditingValue);
    }
  }

  bool _isApplyingDeltas = false;

  @override
  void updateEditingValue(TextEditingValue value) {
    editorImeLog.shout("Delta text input client received a non-delta TextEditingValue from OS: $value");
  }

  @override
  void updateEditingValueWithDeltas(List<TextEditingDelta> textEditingDeltas) {
    if (textEditingDeltas.isEmpty) {
      return;
    }

    editorImeLog.fine("Received edit deltas from platform: ${textEditingDeltas.length} deltas");
    for (final delta in textEditingDeltas) {
      editorImeLog.fine("$delta");
    }

    final imeValueBeforeChange = currentTextEditingValue;
    editorImeLog.fine("IME value before applying deltas: $imeValueBeforeChange");

    _isApplyingDeltas = true;
    editorImeLog.fine("===================================================");
    // Update our local knowledge of what the platform thinks the IME value is right now.
    _updatePlatformImeValueWithDeltas(textEditingDeltas);

    // Apply the deltas to our document, selection, and composing region.
    textDeltasDocumentEditor.applyDeltas(textEditingDeltas);
    editorImeLog.fine("===================================================");
    _isApplyingDeltas = false;

    // Send latest doc and selection to IME
    _sendDocumentToIme();
  }

  bool _isSendingToIme = false;

  void _sendDocumentToIme() {
    if (_isApplyingDeltas) {
      editorImeLog
          .fine("[DocumentImeInputClient] - Tried to send document to IME, but we're applying deltas. Fizzling.");
      return;
    }

    if (_isSendingToIme) {
      editorImeLog
          .warning("[DocumentImeInputClient] - Tried to send document to IME, while we're sending document to IME.");
      return;
    }

    if (textDeltasDocumentEditor.selection.value == null) {
      // There's no selection, which means there's nothing to edit. Return.
      editorImeLog.fine("[DocumentImeInputClient] - There's no document selection. Not sending anything to IME.");
      return;
    }

    _isSendingToIme = true;
    editorImeLog.fine("[DocumentImeInputClient] - Serializing and sending document and selection to IME");
    editorImeLog.fine("[DocumentImeInputClient] - Selection: ${textDeltasDocumentEditor.selection.value}");
    editorImeLog.fine("[DocumentImeInputClient] - Composing region: ${textDeltasDocumentEditor.composingRegion.value}");
    final imeSerialization = DocumentImeSerializer(
      textDeltasDocumentEditor.document,
      textDeltasDocumentEditor.selection.value!,
      textDeltasDocumentEditor.composingRegion.value,
    );

    editorImeLog
        .fine("[DocumentImeInputClient] - Adding invisible characters?: ${imeSerialization.didPrependPlaceholder}");
    TextEditingValue textEditingValue = imeSerialization.toTextEditingValue();

    editorImeLog.fine("[DocumentImeInputClient] - Sending IME serialization:");
    editorImeLog.fine("[DocumentImeInputClient] - $textEditingValue");
    setEditingState(textEditingValue);
    editorImeLog.fine("[DocumentImeInputClient] - Done sending document to IME");

    _isSendingToIme = false;
  }

  @override
  void performAction(TextInputAction action) {
    editorImeLog.fine("IME says to perform action: $action");
    if (action == TextInputAction.newline) {
      textDeltasDocumentEditor.insertNewline();
    }
  }

  @override
  void performSelector(String selectorName) {
    editorImeLog.fine("IME says to perform selector: $selectorName");

    final handler = _selectorHandlers[selectorName];
    if (handler == null) {
      editorImeLog.warning("No handler found for $selectorName");
      return;
    }

    handler(editContext);
  }

  @override
  void performPrivateCommand(String action, Map<String, dynamic> data) {}

  @override
  void showAutocorrectionPromptRect(int start, int end) {}

  @override
  void updateFloatingCursor(RawFloatingCursorPoint point) {
    switch (point.state) {
      case FloatingCursorDragState.Start:
      case FloatingCursorDragState.Update:
        _floatingCursorController?.offset = point.offset;
        break;
      case FloatingCursorDragState.End:
        _floatingCursorController?.offset = null;
        break;
    }
  }

  @override
  void connectionClosed() {
    editorImeLog.info("IME connection was closed");
  }
}

const defaultSelectorHandlers = <String, SelectorHandler>{
  // Movement.
  MacOsSelectors.moveLeft: moveUpstreamWithMoveLeft,
  MacOsSelectors.moveRight: moveDownstreamtWithMoveRight,
  MacOsSelectors.moveUp: moveCaretUpWithMoveUp,
  MacOsSelectors.moveDown: moveCaretDownWithMoveDown,
  MacOsSelectors.moveForward: moveDownstreamtWithMoveRight,
  MacOsSelectors.moveBackward: moveUpstreamWithMoveLeft,
  MacOsSelectors.moveWordLeft: moveWordUpstreamWithMoveWordLeft,
  MacOsSelectors.moveWordRight: moveWordDownstreamWithMoveWordLeft,
  MacOsSelectors.moveToLeftEndOfLine: moveLineUpstreamWithMoveToLeftEndOfLine,
  MacOsSelectors.moveToRightEndOfLine: moveLineDownstreamWithMoveToRightEndOfLine,
  MacOsSelectors.moveToBeginningOfDocument: moveToBeginningOfDocumentWithMoveToBeginningOfDocument,
  MacOsSelectors.moveToEndOfDocument: moveToEndOfDocumentWithMoveToEndOfDocument,

  // static const String moveParagraphBackwardAndModifySelection = 'moveParagraphBackwardAndModifySelection:';
  // static const String moveParagraphForwardAndModifySelection = 'moveParagraphForwardAndModifySelection:';

  // static const String moveToBeginningOfParagraph = 'moveToBeginningOfParagraph:';
  // static const String moveToEndOfParagraph = 'moveToEndOfParagraph:';

  // static const String moveToBeginningOfDocument = 'moveToBeginningOfDocument:';
  // static const String moveToEndOfDocument = 'moveToEndOfDocument:';

  // static const String moveToBeginningOfDocumentAndModifySelection = 'moveToBeginningOfDocumentAndModifySelection:';
  // static const String moveToEndOfDocumentAndModifySelection = 'moveToEndOfDocumentAndModifySelection:';

  // Selection expanding.
  MacOsSelectors.moveLeftAndModifySelection: expandSelectionUpstreamWithMoveLeftAndModifySelection,
  MacOsSelectors.moveRightAndModifySelection: expandSelectionDownstreamWithMoveRightAndModifySelection,
  MacOsSelectors.moveUpAndModifySelection: expandSelectionLineUpWithMoveUpAndModifySelection,
  MacOsSelectors.moveDownAndModifySelection: expandSelectionLineDownWithMoveUpAndModifySelection,
  MacOsSelectors.moveWordLeftAndModifySelection: expandSelectionWordUpstreamWithMoveWordLeftAndModifySelection,
  MacOsSelectors.moveWordRightAndModifySelection: expandSelectionWordDownstreamWithMoveWordRightAndModifySelection,
  MacOsSelectors.moveToLeftEndOfLineAndModifySelection:
      expandSelectionLineUpstreamWithMoveToLeftEndOfLineAndModifySelection,
  MacOsSelectors.moveToRightEndOfLineAndModifySelection:
      expandSelectionLineDownstreamWithMoveToRightEndOfLineAndModifySelection,

  // static const String pageUpAndModifySelection = 'pageUpAndModifySelection:';
  // static const String pageDownAndModifySelection = 'pageDownAndModifySelection:';

  // Deletion.
  MacOsSelectors.deleteBackward: deleteUpstreamOnDeleteBackward,
  MacOsSelectors.deleteForward: deleteDownstreamContentWithDeleteForward,
  MacOsSelectors.deleteWordBackward: deleteWordUpstreamWithDeletWordBackward,
  MacOsSelectors.deleteWordForward: deleteWordDownstreamWithDeletWordForward,
  MacOsSelectors.deleteToBeginningOfLine: deleteToStartOfLineWithDeleteToBeginningOfLine,
  MacOsSelectors.deleteToEndOfLine: deleteToEndOfLineWithDeleteToEndOfLine,
  MacOsSelectors.deleteBackwardByDecomposingPreviousCharacter: deleteUpstreamOnDeleteBackward,

  // Scrolling.
  MacOsSelectors.scrollToBeginningOfDocument: scrollToBeginningOfDocumentScrollToBeginningOfDocument,
  MacOsSelectors.scrollToEndOfDocument: scrollToEndOfDocumentScrollToEndOfDocument,
  MacOsSelectors.scrollPageUp: scrollToStarOfPageWithScrollPageUp,
  MacOsSelectors.scrollPageDown: scrollToEndOfPageWithScrollPageDown,

  // Insertion.
  MacOsSelectors.insertTab: indentListItem,
  MacOsSelectors.insertBacktab: unIndentListItem,

  // static const String transpose = 'transpose:';
  // static const String cancelOperation = 'cancelOperation:';
};

void moveToBeginningOfDocumentWithMoveToBeginningOfDocument(SuperEditorContext context) {
  //
}

void moveToEndOfDocumentWithMoveToEndOfDocument(SuperEditorContext context) {
  //
}

void deleteUpstreamOnDeleteBackward(SuperEditorContext context) {
  context.commonOps.deleteUpstream();
}

void deleteDownstreamContentWithDeleteForward(SuperEditorContext context) {
  context.commonOps.deleteDownstream();
}

void moveUpstreamWithMoveLeft(SuperEditorContext context) {
  context.commonOps.moveCaretUpstream();
}

void expandSelectionUpstreamWithMoveLeftAndModifySelection(SuperEditorContext context) {
  context.commonOps.moveCaretUpstream(expand: true);
}

void expandSelectionDownstreamWithMoveRightAndModifySelection(SuperEditorContext context) {
  context.commonOps.moveCaretDownstream(expand: true);
}

void moveDownstreamtWithMoveRight(SuperEditorContext context) {
  context.commonOps.moveCaretDownstream();
}

void moveCaretUpWithMoveUp(SuperEditorContext context) {
  context.commonOps.moveCaretUp();
}

void moveCaretDownWithMoveDown(SuperEditorContext context) {
  context.commonOps.moveCaretDown();
}

void moveWordUpstreamWithMoveWordLeft(SuperEditorContext context) {
  context.commonOps.moveCaretUpstream(movementModifier: MovementModifier.word);
}

void moveWordDownstreamWithMoveWordLeft(SuperEditorContext context) {
  context.commonOps.moveCaretDownstream(movementModifier: MovementModifier.word);
}

void moveLineUpstreamWithMoveToLeftEndOfLine(SuperEditorContext context) {
  context.commonOps.moveCaretUpstream(movementModifier: MovementModifier.line);
}

void moveLineDownstreamWithMoveToRightEndOfLine(SuperEditorContext context) {
  context.commonOps.moveCaretDownstream(movementModifier: MovementModifier.line);
}

void expandSelectionLineUpWithMoveUpAndModifySelection(SuperEditorContext context) {
  context.commonOps.moveCaretUp(expand: true);
}

void expandSelectionLineDownWithMoveUpAndModifySelection(SuperEditorContext context) {
  context.commonOps.moveCaretDown(expand: true);
}

void expandSelectionWordUpstreamWithMoveWordLeftAndModifySelection(SuperEditorContext context) {
  context.commonOps.moveCaretUpstream(
    expand: true,
    movementModifier: MovementModifier.word,
  );
}

void expandSelectionWordDownstreamWithMoveWordRightAndModifySelection(SuperEditorContext context) {
  context.commonOps.moveCaretDownstream(
    expand: true,
    movementModifier: MovementModifier.word,
  );
}

void expandSelectionLineUpstreamWithMoveToLeftEndOfLineAndModifySelection(SuperEditorContext context) {
  context.commonOps.moveCaretUpstream(
    expand: true,
    movementModifier: MovementModifier.line,
  );
}

void expandSelectionLineDownstreamWithMoveToRightEndOfLineAndModifySelection(SuperEditorContext context) {
  context.commonOps.moveCaretDownstream(
    expand: true,
    movementModifier: MovementModifier.line,
  );
}

void deleteWordUpstreamWithDeletWordBackward(SuperEditorContext context) {
  bool didMove = false;

  didMove = context.commonOps.moveCaretUpstream(
    expand: true,
    movementModifier: MovementModifier.word,
  );

  if (didMove) {
    context.commonOps.deleteSelection();
  }
}

void deleteWordDownstreamWithDeletWordForward(SuperEditorContext context) {
  bool didMove = false;

  didMove = context.commonOps.moveCaretDownstream(
    expand: true,
    movementModifier: MovementModifier.word,
  );

  if (didMove) {
    context.commonOps.deleteSelection();
  }
}

void deleteToStartOfLineWithDeleteToBeginningOfLine(SuperEditorContext context) {
  bool didMove = false;

  didMove = context.commonOps.moveCaretUpstream(
    expand: true,
    movementModifier: MovementModifier.line,
  );

  if (didMove) {
    context.commonOps.deleteSelection();
  }
}

void deleteToEndOfLineWithDeleteToEndOfLine(SuperEditorContext context) {
  bool didMove = false;

  didMove = context.commonOps.moveCaretDownstream(
    expand: true,
    movementModifier: MovementModifier.line,
  );

  if (didMove) {
    context.commonOps.deleteSelection();
  }
}

void scrollToBeginningOfDocumentScrollToBeginningOfDocument(SuperEditorContext context) {
  context.scroller.animateTo(
    context.scroller.minScrollExtent,
    duration: const Duration(milliseconds: 150),
    curve: Curves.decelerate,
  );
}

void scrollToEndOfDocumentScrollToEndOfDocument(SuperEditorContext context) {
  context.scroller.animateTo(
    context.scroller.maxScrollExtent,
    duration: const Duration(milliseconds: 150),
    curve: Curves.decelerate,
  );
}

void scrollToStarOfPageWithScrollPageUp(SuperEditorContext context) {
  context.scroller.animateTo(
    max(context.scroller.scrollOffset - context.scroller.viewportDimension, context.scroller.minScrollExtent),
    duration: const Duration(milliseconds: 150),
    curve: Curves.decelerate,
  );
}

void scrollToEndOfPageWithScrollPageDown(SuperEditorContext context) {
  context.scroller.animateTo(
    min(context.scroller.scrollOffset + context.scroller.viewportDimension, context.scroller.maxScrollExtent),
    duration: const Duration(milliseconds: 150),
    curve: Curves.decelerate,
  );
}

void indentListItem(SuperEditorContext context) {
  context.commonOps.indentListItem();
}

void unIndentListItem(SuperEditorContext context) {
  context.commonOps.unindentListItem();
}

//   shiftEnterToInsertNewlineInBlock,
//   deleteToEndOfLineWithCmdDeleteOnMac,

typedef SelectorHandler = void Function(SuperEditorContext context);

class MacOsSelectors {
  static const String deleteBackward = 'deleteBackward:';
  static const String deleteWordBackward = 'deleteWordBackward:';
  static const String deleteToBeginningOfLine = 'deleteToBeginningOfLine:';
  static const String deleteForward = 'deleteForward:';
  static const String deleteWordForward = 'deleteWordForward:';
  static const String deleteToEndOfLine = 'deleteToEndOfLine:';
  static const String deleteBackwardByDecomposingPreviousCharacter = 'deleteBackwardByDecomposingPreviousCharacter:';

  static const String moveLeft = 'moveLeft:';
  static const String moveRight = 'moveRight:';
  static const String moveForward = 'moveForward:';
  static const String moveBackward = 'moveBackward:';
  static const String moveUp = 'moveUp:';
  static const String moveDown = 'moveDown:';

  static const String moveWordLeft = 'moveWordLeft:';
  static const String moveWordRight = 'moveWordRight:';
  static const String moveToBeginningOfParagraph = 'moveToBeginningOfParagraph:';
  static const String moveToEndOfParagraph = 'moveToEndOfParagraph:';

  static const String moveToLeftEndOfLine = 'moveToLeftEndOfLine:';
  static const String moveToRightEndOfLine = 'moveToRightEndOfLine:';
  static const String moveToBeginningOfDocument = 'moveToBeginningOfDocument:';
  static const String moveToEndOfDocument = 'moveToEndOfDocument:';

  static const String moveLeftAndModifySelection = 'moveLeftAndModifySelection:';
  static const String moveRightAndModifySelection = 'moveRightAndModifySelection:';
  static const String moveUpAndModifySelection = 'moveUpAndModifySelection:';
  static const String moveDownAndModifySelection = 'moveDownAndModifySelection:';

  static const String moveWordLeftAndModifySelection = 'moveWordLeftAndModifySelection:';
  static const String moveWordRightAndModifySelection = 'moveWordRightAndModifySelection:';
  static const String moveParagraphBackwardAndModifySelection = 'moveParagraphBackwardAndModifySelection:';
  static const String moveParagraphForwardAndModifySelection = 'moveParagraphForwardAndModifySelection:';

  static const String moveToLeftEndOfLineAndModifySelection = 'moveToLeftEndOfLineAndModifySelection:';
  static const String moveToRightEndOfLineAndModifySelection = 'moveToRightEndOfLineAndModifySelection:';
  static const String moveToBeginningOfDocumentAndModifySelection = 'moveToBeginningOfDocumentAndModifySelection:';
  static const String moveToEndOfDocumentAndModifySelection = 'moveToEndOfDocumentAndModifySelection:';

  static const String transpose = 'transpose:';

  static const String scrollToBeginningOfDocument = 'scrollToBeginningOfDocument:';
  static const String scrollToEndOfDocument = 'scrollToEndOfDocument:';

  static const String scrollPageUp = 'scrollPageUp:';
  static const String scrollPageDown = 'scrollPageDown:';
  static const String pageUpAndModifySelection = 'pageUpAndModifySelection:';
  static const String pageDownAndModifySelection = 'pageDownAndModifySelection:';

  static const String cancelOperation = 'cancelOperation:';
  static const String insertTab = 'insertTab:';
  static const String insertBacktab = 'insertBacktab:';
}
