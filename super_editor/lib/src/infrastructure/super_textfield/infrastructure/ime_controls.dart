import 'package:flutter/material.dart';
import 'package:flutter/src/foundation/key.dart';
import 'package:flutter/src/widgets/framework.dart';
import 'package:flutter/src/widgets/placeholder.dart';
import 'package:super_editor/src/infrastructure/super_textfield/super_textfield.dart';
import 'package:super_text_layout/super_text_layout.dart';

class SuperTextFieldImeControls extends StatefulWidget {
  const SuperTextFieldImeControls({
    Key? key,
    required this.textController,
    required this.textKey,
    required this.focusNode,
    required this.child,
  }) : super(key: key);

  final ImeAttributedTextEditingController textController;

  /// [FocusNode] of thee text field.
  final FocusNode focusNode;

  /// [GlobalKey] that links this [SuperTextFieldGestureInteractor] to
  /// the [ProseTextLayout] widget that paints the text for this text field.
  final GlobalKey<ProseTextState> textKey;

  final Widget child;

  @override
  State<SuperTextFieldImeControls> createState() => _SuperTextFieldImeControlsState();
}

class _SuperTextFieldImeControlsState extends State<SuperTextFieldImeControls> {
  @override
  void initState() {
    super.initState();
    widget.textController.addListener(_onContentChanged);

    widget.focusNode.addListener(_onFocusChanged);

    if (widget.focusNode.hasFocus) {
      // We got an already focused FocusNode, we need to update the IME controls.
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
        _onFocusChanged();
      });
    }
  }

  @override
  void didUpdateWidget(covariant SuperTextFieldImeControls oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.textController != oldWidget.textController) {
      oldWidget.textController.removeListener(_onContentChanged);
      widget.textController.addListener(_onContentChanged);
    }

    if (widget.focusNode != oldWidget.focusNode) {
      oldWidget.focusNode.removeListener(_onFocusChanged);
      widget.focusNode.addListener(_onFocusChanged);

      if (widget.focusNode.hasFocus) {
        // We got an already focused FocusNode, we need to attach to the IME.
        WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
          _onFocusChanged();
        });
      }
    }
  }

  @override
  void dispose() {
    widget.textController.removeListener(_onContentChanged);
    widget.focusNode.removeListener(_onFocusChanged);
    super.dispose();
  }

  void _onFocusChanged() {
    if (!widget.focusNode.hasFocus) {
      return;
    }

    _updateImeVisualInformation();

    widget.textController.showKeyboard();
  }

  void _onContentChanged() {
    _updateImeVisualInformation();
  }

  void _updateComposingRectIfNeeded() {
    if (!widget.textController.isAttachedToIme) {
      return;
    }

    final composingRegion = widget.textController.composingRegion;

    final text = widget.textKey.currentState;
    if (text == null) {
      return;
    }

    final selection = widget.textController.selection;
    if (!selection.isValid) {
      return;
    }

    final textLayout = text.textLayout;

    final boxes = textLayout.getBoxesForSelection(selection);
    if (boxes.isEmpty) {
      return;
    }

    final composingRect = boxes.first.toRect();

    //final box = textLayout.getCharacterBox(TextPosition(offset: selection.baseOffset));

    widget.textController.setComposingRect(composingRect);

    //SchedulerBinding.instance.addPostFrameCallback((Duration _) => _updateComposingRectIfNeeded());
  }

  void _updateCaretRectIfNeeded() {
    if (!widget.textController.isAttachedToIme) {
      return;
    }

    //SchedulerBinding.instance.addPostFrameCallback((Duration _) => _updateCaretRectIfNeeded());

    final text = widget.textKey.currentState;
    if (text == null) {
      return;
    }

    final textLayout = text.textLayout;

    final selection = widget.textController.selection;
    if (!selection.isValid || !selection.isCollapsed) {
      return;
    }

    //final TextPosition currentTextPosition = TextPosition(offset: renderEditable.selection!.baseOffset);
    final textRenderBox = text.context.findRenderObject() as RenderBox;
    final myRenderBox = context.findRenderObject() as RenderBox;

    final textOffset = myRenderBox.globalToLocal(textRenderBox.localToGlobal(Offset.zero));

    final position = TextPosition(offset: selection.baseOffset);
    final caretOffset = textLayout.getOffsetForCaret(position);
    final caretHeight = textLayout.getHeightForCaret(position) ?? 0;
    //final box = textLayout.getCharacterBox(TextPosition(offset: selection.baseOffset));
    final box = caretOffset & Size(1, caretHeight);

    if (box == null) {
      return;
    }

    widget.textController.setCaretRect(box.shift(textOffset));
  }

  void _updateSizeAndTransform() {
    if (!widget.textController.isAttachedToIme) {
      return;
    }

    final renderBox = context.findRenderObject() as RenderBox;
    final transform = renderBox.getTransformTo(null); //

    widget.textController.setEditableSizeAndTransform(renderBox.size, transform);

    //SchedulerBinding.instance.addPostFrameCallback((Duration _) => _updateSizeAndTransform());
  }

  void _updateImeVisualInformation() {
    _updateSizeAndTransform();
    _updateCaretRectIfNeeded();
    _updateComposingRectIfNeeded();
    widget.textController.showKeyboard();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
