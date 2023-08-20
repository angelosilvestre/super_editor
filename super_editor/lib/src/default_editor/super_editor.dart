import 'package:attributed_text/attributed_text.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart' hide SelectableText;
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_composer.dart';
import 'package:super_editor/src/core/document_debug_paint.dart';
import 'package:super_editor/src/core/document_interaction.dart';
import 'package:super_editor/src/core/document_layout.dart';
import 'package:super_editor/src/core/edit_context.dart';
import 'package:super_editor/src/core/editor.dart';
import 'package:super_editor/src/core/styles.dart';
import 'package:super_editor/src/default_editor/common_editor_operations.dart';
import 'package:super_editor/src/default_editor/debug_visualization.dart';
import 'package:super_editor/src/default_editor/document_gestures_touch_android.dart';
import 'package:super_editor/src/default_editor/document_gestures_touch_ios.dart';
import 'package:super_editor/src/default_editor/document_scrollable.dart';
import 'package:super_editor/src/default_editor/list_items.dart';
import 'package:super_editor/src/default_editor/tasks.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';
import 'package:super_editor/src/infrastructure/documents/document_scaffold.dart';
import 'package:super_editor/src/infrastructure/documents/document_scroller.dart';
import 'package:super_editor/src/infrastructure/links.dart';
import 'package:super_editor/src/infrastructure/platforms/ios/ios_document_controls.dart';
import 'package:super_editor/src/infrastructure/selection_leader_document_layer.dart';
import 'package:super_editor/src/infrastructure/text_input.dart';
import 'package:super_text_layout/super_text_layout.dart';

import '../infrastructure/document_gestures_interaction_overrides.dart';
import '../infrastructure/platforms/mobile_documents.dart';
import 'attributions.dart';
import 'blockquote.dart';
import 'document_caret_overlay.dart';
import 'document_focus_and_selection_policies.dart';
import 'document_gestures_mouse.dart';
import 'document_hardware_keyboard/document_input_keyboard.dart';
import 'document_ime/document_input_ime.dart';
import 'horizontal_rule.dart';
import 'image.dart';
import 'layout_single_column/layout_single_column.dart';
import 'paragraph.dart';
import 'text.dart';
import 'unknown_component.dart';

/// A rich text editor that displays a document in a single-column layout.
///
/// A [SuperEditor] brings together the key pieces needed
/// to display a user-editable document:
///  * document model
///  * document editor
///  * document layout
///  * document interaction (tapping, dragging, typing, scrolling)
///  * document composer (current selection, and styles to apply to next character)
///
/// A [SuperEditor] determines the visual styling by way of:
///  * [stylesheet], which applies styles throughout the document layout,
///    including text styles and block padding.
///  * [componentStyles], which applies targeted styles to specific components
///    in the document layout.
///  * [componentBuilders], which produce every visual component within the document layout.
///  * [selectionStyles], which dictates the color of the caret and the color of
///    selected text and components
///
/// A [SuperEditor] determines how a physical keyboard interacts with the document
/// by way of [keyboardActions].
///
/// A [SuperEditor] works with software keyboards through the platform's Input Method
/// Engine (IME). To customize how [SuperEditor] works with the IME, see [imePolicies],
/// [imeConfiguration], and [softwareKeyboardController].
///
/// ## Deeper explanation of core artifacts:
///
/// The document model is responsible for holding the content of a
/// document in a structured and query-able manner.
///
/// The document editor is responsible for mutating the document
/// structure.
///
/// Document layout is responsible for positioning and rendering the
/// various visual components in the document. It's also responsible
/// for linking logical document nodes to visual document components
/// to facilitate user interactions like tapping and dragging.
///
/// Document interaction is responsible for taking appropriate actions
/// in response to user taps, drags, and key presses.
///
/// Document composer is responsible for owning document selection and
/// the current text entry mode.
class SuperEditor extends StatefulWidget {
  /// Creates a `Super Editor` with common (but configurable) defaults for
  /// visual components, text styles, and user interaction.
  SuperEditor({
    Key? key,
    this.focusNode,
    required this.editor,
    required this.document,
    required this.composer,
    this.scrollController,
    this.documentLayoutKey,
    Stylesheet? stylesheet,
    this.customStylePhases = const [],
    List<ComponentBuilder>? componentBuilders,
    SelectionStyles? selectionStyle,
    this.selectionPolicies = const SuperEditorSelectionPolicies(),
    this.inputSource,
    this.softwareKeyboardController,
    this.imePolicies = const SuperEditorImePolicies(),
    this.imeConfiguration = const SuperEditorImeConfiguration(),
    this.imeOverrides,
    List<DocumentKeyboardAction>? keyboardActions,
    this.gestureMode,
    this.contentTapDelegateFactory = superEditorLaunchLinkTapHandlerFactory,
    this.androidHandleColor,
    this.androidToolbarBuilder,
    this.iOSHandleColor,
    this.iOSToolbarBuilder,
    this.createOverlayControlsClipper,
    this.selectionLayerLinks,
    this.documentOverlayBuilders = const [DefaultCaretOverlayBuilder()],
    this.autofocus = false,
    this.overlayController,
    this.plugins = const {},
    this.debugPaint = const DebugPaintConfig(),
  })  : stylesheet = stylesheet ?? defaultStylesheet,
        selectionStyles = selectionStyle ?? defaultSelectionStyle,
        keyboardActions = keyboardActions ??
            (inputSource == TextInputSource.ime ? defaultImeKeyboardActions : defaultKeyboardActions),
        componentBuilders = componentBuilders != null
            ? [...componentBuilders, const UnknownComponentBuilder()]
            : [...defaultComponentBuilders, const UnknownComponentBuilder()],
        super(key: key);

  /// [FocusNode] for the entire `SuperEditor`.
  final FocusNode? focusNode;

  /// Whether or not the [SuperEditor] should autofocus
  final bool autofocus;

  /// The [ScrollController] that governs this `SuperEditor`'s scroll
  /// offset.
  ///
  /// `scrollController` is not used if this `SuperEditor` has an ancestor
  /// `Scrollable`.
  final ScrollController? scrollController;

  /// Shows, hides, and positions a floating toolbar and magnifier.
  final MagnifierAndToolbarController? overlayController;

  /// [GlobalKey] that's bound to the [DocumentLayout] within
  /// this `SuperEditor`.
  ///
  /// This key can be used to lookup visual components in the document
  /// layout within this `SuperEditor`.
  final GlobalKey? documentLayoutKey;

  /// Style rules applied through the document presentation.
  final Stylesheet stylesheet;

  /// Styles applied to selected content.
  final SelectionStyles selectionStyles;

  /// Policies that determine how selection is modified by other factors, such as
  /// gaining or losing focus.
  final SuperEditorSelectionPolicies selectionPolicies;

  /// Custom style phases that are added to the standard style phases.
  ///
  /// Documents are styled in a series of phases. A number of such
  /// phases are applied, automatically, e.g., text styles, per-component
  /// styles, and content selection styles.
  ///
  /// [customStylePhases] are added after the standard style phases. You can
  /// use custom style phases to apply styles that aren't supported with
  /// [stylesheet]s.
  ///
  /// You can also use them to apply styles to your custom [DocumentNode]
  /// types that aren't supported by Super Editor. For example, Super Editor
  /// doesn't include support for tables within documents, but you could
  /// implement a `TableNode` for that purpose. You may then want to make your
  /// table styleable. To accomplish this, you add a custom style phase that
  /// knows how to interpret and apply table styles for your visual table component.
  final List<SingleColumnLayoutStylePhase> customStylePhases;

  /// The `SuperEditor` input source, e.g., keyboard or Input Method Engine.
  final TextInputSource? inputSource;

  /// Opens and closes the software keyboard.
  ///
  /// Typically, this controller should only be used when the keyboard is configured
  /// for manual control, e.g., [SuperEditorImePolicies.openKeyboardOnSelectionChange] and
  /// [SuperEditorImePolicies.clearSelectionWhenEditorLosesFocus] are `false`. Otherwise,
  /// the automatic behavior might conflict with commands to this controller.
  final SoftwareKeyboardController? softwareKeyboardController;

  /// Policies that dictate when and how [SuperEditor] should interact with the
  /// platform IME, such as automatically opening the software keyboard when
  /// [SuperEditor]'s selection changes.
  final SuperEditorImePolicies imePolicies;

  /// Preferences for how the platform IME should look and behave during editing.
  final SuperEditorImeConfiguration imeConfiguration;

  /// Overrides for IME actions.
  ///
  /// When the user edits document content in IME mode, those edits and actions
  /// are reported to a [DeltaTextInputClient], which is then responsible for
  /// applying those changes to a document. [SuperEditor] includes an implementation
  /// for all relevant editing behaviors. However, some apps may wish to implement
  /// their own custom behavior, such as when the user presses the action button,
  /// such as "Next" or "Done".
  ///
  /// Provide a [DeltaTextInputClientDecorator], to override the default [SuperEditor]
  /// behaviors for various IME messages.
  final DeltaTextInputClientDecorator? imeOverrides;

  /// The `SuperEditor` gesture mode, e.g., mouse or touch.
  final DocumentGestureMode? gestureMode;

  /// Factory that creates a [ContentTapDelegate], which is given an
  /// opportunity to respond to taps on content before the editor, itself.
  ///
  /// A [ContentTapDelegate] might be used, for example, to launch a URL
  /// when a user taps on a link.
  final SuperEditorContentTapDelegateFactory? contentTapDelegateFactory;

  /// Color of the text selection drag handles on Android.
  final Color? androidHandleColor;

  /// Builder that creates a floating toolbar when running on Android.
  final WidgetBuilder? androidToolbarBuilder;

  /// Color of the text selection drag handles on iOS.
  final Color? iOSHandleColor;

  /// Builder that creates a floating toolbar when running on iOS.
  final WidgetBuilder? iOSToolbarBuilder;

  /// Creates a clipper that applies to overlay controls, like drag
  /// handles, magnifiers, and popover toolbars, preventing the overlay
  /// controls from appearing outside the given clipping region.
  ///
  /// If no clipper factory method is provided, then the overlay controls
  /// will be allowed to appear anywhere in the overlay in which they sit
  /// (probably the entire screen).
  final CustomClipper<Rect> Function(BuildContext overlayContext)? createOverlayControlsClipper;

  /// Leader links that connect leader widgets near the user's selection
  /// to carets, handles, and other things that want to follow the selection.
  ///
  /// These links are always created and used within [SuperEditor]. By providing
  /// an explicit [selectionLayerLinks], external widgets can also follow the
  /// user's selection.
  final SelectionLayerLinks? selectionLayerLinks;

  /// Alters the [document] and other artifacts.
  final Editor editor;

  /// The [Document] that's edited by the [editor].
  final Document document;

  /// Layers that are displayed on top of the document layout, aligned
  /// with the location and size of the document layout.
  final List<SuperEditorLayerBuilder> documentOverlayBuilders;

  /// Owns the editor's current selection, the current attributions for
  /// text input, and other transitive editor configurations.
  final DocumentComposer composer;

  /// Priority list of widget factories that create instances of
  /// each visual component displayed in the document layout, e.g.,
  /// paragraph component, image component, horizontal rule component, etc.
  final List<ComponentBuilder> componentBuilders;

  /// All actions that this editor takes in response to key
  /// events, e.g., text entry, newlines, character deletion,
  /// copy, paste, etc.
  ///
  /// These actions are only used when in [TextInputSource.keyboard]
  /// mode.
  final List<DocumentKeyboardAction> keyboardActions;

  /// Plugins that add sets of behaviors to the editing experience.
  final Set<SuperEditorPlugin> plugins;

  /// Paints some extra visual ornamentation to help with
  /// debugging.
  final DebugPaintConfig debugPaint;

  @override
  SuperEditorState createState() => SuperEditorState();
}

@visibleForTesting
class SuperEditorState extends State<SuperEditor> {
  // GlobalKey used to access the [DocumentLayoutState] to figure
  // out where in the document the user taps or drags.
  late GlobalKey _docLayoutKey;
  final _documentLayoutLink = LayerLink();
  SingleColumnLayoutPresenter? _docLayoutPresenter;
  late SingleColumnStylesheetStyler _docStylesheetStyler;
  late SingleColumnLayoutCustomComponentStyler _docLayoutPerComponentBlockStyler;
  late SingleColumnLayoutSelectionStyler _docLayoutSelectionStyler;

  late FocusNode _focusNode;
  @visibleForTesting
  FocusNode get focusNode => _focusNode;

  late DocumentComposer _composer;

  late DocumentScroller _scroller;
  late ScrollController _scrollController;
  late AutoScrollController _autoScrollController;

  @visibleForTesting
  late SuperEditorContext editContext;

  ContentTapDelegate? _contentTapDelegate;

  final _floatingCursorController = FloatingCursorController();

  // Leader links that connect leader widgets near the user's selection
  // to carets, handles, and other things that want to follow the selection.
  late SelectionLayerLinks _selectionLinks;

  @visibleForTesting
  SingleColumnLayoutPresenter get presenter => _docLayoutPresenter!;

  @override
  void initState() {
    super.initState();

    _focusNode = (widget.focusNode ?? FocusNode())..addListener(_onFocusChange);

    _composer = widget.composer;

    _scrollController = widget.scrollController ?? ScrollController();
    _autoScrollController = AutoScrollController();

    _docLayoutKey = widget.documentLayoutKey ?? GlobalKey();

    _selectionLinks = widget.selectionLayerLinks ?? SelectionLayerLinks();

    widget.editor.context.put(
      Editor.layoutKey,
      DocumentLayoutEditable(() => _docLayoutKey.currentState as DocumentLayout),
    );

    _createEditContext();
    _createLayoutPresenter();
  }

  @override
  void didUpdateWidget(SuperEditor oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.focusNode != oldWidget.focusNode) {
      _focusNode = (widget.focusNode ?? FocusNode())..addListener(_onFocusChange);
    }

    if (widget.documentLayoutKey != oldWidget.documentLayoutKey) {
      _docLayoutKey = widget.documentLayoutKey ?? GlobalKey();
    }

    if (widget.selectionLayerLinks != oldWidget.selectionLayerLinks) {
      _selectionLinks = widget.selectionLayerLinks ?? SelectionLayerLinks();
    }

    if (widget.editor != oldWidget.editor) {
      for (final plugin in oldWidget.plugins) {
        plugin.detach(oldWidget.editor);
      }

      oldWidget.editor.context.remove(Editor.layoutKey);
      widget.editor.context.put(
        Editor.layoutKey,
        DocumentLayoutEditable(() => _docLayoutKey.currentState as DocumentLayout),
      );

      _createEditContext();
      _createLayoutPresenter();
    } else if (widget.selectionStyles != oldWidget.selectionStyles) {
      _docLayoutSelectionStyler.selectionStyles = widget.selectionStyles;
    }

    if (widget.stylesheet != oldWidget.stylesheet) {
      _docStylesheetStyler.stylesheet = widget.stylesheet;
    }

    if (widget.scrollController != oldWidget.scrollController) {
      _scrollController = widget.scrollController ?? ScrollController();
    }

    _recomputeIfLayoutShouldShowCaret();
  }

  @override
  void dispose() {
    _contentTapDelegate?.dispose();

    widget.editor.context.remove(Editor.layoutKey);

    _focusNode.removeListener(_onFocusChange);
    if (widget.focusNode == null) {
      // We are using our own private FocusNode. Dispose it.
      _focusNode.dispose();
    }

    super.dispose();
  }

  void _createEditContext() {
    _scroller = DocumentScroller();

    editContext = SuperEditorContext(
      editor: widget.editor,
      document: widget.document,
      composer: _composer,
      getDocumentLayout: () => _docLayoutKey.currentState as DocumentLayout,
      scroller: _scroller,
      commonOps: CommonEditorOperations(
        editor: widget.editor,
        document: widget.document,
        composer: _composer,
        documentLayoutResolver: () => _docLayoutKey.currentState as DocumentLayout,
      ),
    );

    for (final plugin in widget.plugins) {
      plugin.attach(widget.editor);
    }

    // The ContentTapDelegate depends upon the EditContext. Recreate the
    // delegate, now that we've created a new EditContext.
    _contentTapDelegate?.dispose();
    _contentTapDelegate = widget.contentTapDelegateFactory?.call(editContext);
  }

  void _createLayoutPresenter() {
    if (_docLayoutPresenter != null) {
      _docLayoutPresenter!.dispose();
    }

    final document = editContext.document;

    _docStylesheetStyler = SingleColumnStylesheetStyler(stylesheet: widget.stylesheet);

    _docLayoutPerComponentBlockStyler = SingleColumnLayoutCustomComponentStyler();

    _docLayoutSelectionStyler = SingleColumnLayoutSelectionStyler(
      document: document,
      selection: editContext.composer.selectionNotifier,
      selectionStyles: widget.selectionStyles,
    );

    _docLayoutPresenter = SingleColumnLayoutPresenter(
      document: document,
      componentBuilders: widget.componentBuilders,
      pipeline: [
        _docStylesheetStyler,
        _docLayoutPerComponentBlockStyler,
        ...widget.customStylePhases,
        // Selection changes are very volatile. Put that phase last
        // to minimize view model recalculations.
        _docLayoutSelectionStyler,
      ],
    );

    _recomputeIfLayoutShouldShowCaret();
  }

  void _onFocusChange() {
    _recomputeIfLayoutShouldShowCaret();
  }

  void _recomputeIfLayoutShouldShowCaret() {
    _docLayoutSelectionStyler.shouldDocumentShowCaret = _focusNode.hasFocus && gestureMode == DocumentGestureMode.mouse;
  }

  @visibleForTesting
  DocumentGestureMode get gestureMode {
    if (widget.gestureMode != null) {
      return widget.gestureMode!;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return DocumentGestureMode.android;
      case TargetPlatform.iOS:
        return DocumentGestureMode.iOS;
      default:
        return DocumentGestureMode.mouse;
    }
  }

  /// Returns the [TextInputSource] which should be used.
  ///
  /// If the `inputSource` is configured, it is used. Otherwise,
  /// the [TextInputSource] is chosen based on the platform.
  @visibleForTesting
  TextInputSource get inputSource => widget.inputSource ?? TextInputSource.ime;

  @override
  Widget build(BuildContext context) {
    return SuperEditorFocusDebugVisuals(
      focusNode: _focusNode,
      child: EditorSelectionAndFocusPolicy(
        focusNode: _focusNode,
        editor: widget.editor,
        document: widget.document,
        selection: _composer.selectionNotifier,
        isDocumentLayoutAvailable: () => _docLayoutKey.currentContext != null,
        getDocumentLayout: () => editContext.documentLayout,
        placeCaretAtEndOfDocumentOnGainFocus: widget.selectionPolicies.placeCaretAtEndOfDocumentOnGainFocus,
        restorePreviousSelectionOnGainFocus: widget.selectionPolicies.restorePreviousSelectionOnGainFocus,
        clearSelectionWhenEditorLosesFocus: widget.selectionPolicies.clearSelectionWhenEditorLosesFocus,
        child: _buildInputSystem(
          child: DocumentScaffold(
            documentLayoutLink: _documentLayoutLink,
            documentLayoutKey: _docLayoutKey,
            gestureBuilder: _buildGestureInteractor,
            scrollController: _scrollController,
            autoScrollController: _autoScrollController,
            scroller: _scroller,
            presenter: presenter,
            componentBuilders: widget.componentBuilders,
            overlays: [
              // Layer that positions and sizes leader widgets at the bounds
              // of the users selection so that carets, handles, toolbars, and
              // other things can follow the selection.
              (context) {
                return _SelectionLeadersDocumentLayerBuilder(
                  links: _selectionLinks,
                ).build(context, editContext);
              },
              // Add all overlays that the app wants.
              for (final overlayBuilder in widget.documentOverlayBuilders) //
                (context) => overlayBuilder.build(context, editContext),
            ],
            debugPaint: widget.debugPaint,
          ),
        ),
      ),
    );
  }

  /// Builds the widget tree that applies user input, e.g., key
  /// presses from a keyboard, or text deltas from the IME.
  Widget _buildInputSystem({
    required Widget child,
  }) {
    switch (inputSource) {
      case TextInputSource.keyboard:
        return SuperEditorHardwareKeyHandler(
          focusNode: _focusNode,
          autofocus: widget.autofocus,
          editContext: editContext,
          keyboardActions: [
            for (final plugin in widget.plugins) //
              ...plugin.keyboardActions,
            ...widget.keyboardActions,
          ],
          child: child,
        );
      case TextInputSource.ime:
        return SuperEditorImeInteractor(
          focusNode: _focusNode,
          autofocus: widget.autofocus,
          editContext: editContext,
          clearSelectionWhenEditorLosesFocus: widget.selectionPolicies.clearSelectionWhenEditorLosesFocus,
          clearSelectionWhenImeConnectionCloses: widget.selectionPolicies.clearSelectionWhenImeConnectionCloses,
          softwareKeyboardController: widget.softwareKeyboardController,
          imePolicies: widget.imePolicies,
          imeConfiguration: widget.imeConfiguration,
          imeOverrides: widget.imeOverrides,
          hardwareKeyboardActions: [
            for (final plugin in widget.plugins) //
              ...plugin.keyboardActions,
            ...widget.keyboardActions,
          ],
          floatingCursorController: _floatingCursorController,
          child: child,
        );
    }
  }

  Widget _buildGestureInteractor(BuildContext context) {
    switch (gestureMode) {
      case DocumentGestureMode.mouse:
        return _buildDesktopGestureSystem();
      case DocumentGestureMode.android:
        return _buildAndroidGestureSystem();
      case DocumentGestureMode.iOS:
        return _buildIOSGestureSystem();
    }
  }

  Widget _buildDesktopGestureSystem() {
    return DocumentMouseInteractor(
      focusNode: _focusNode,
      editor: editContext.editor,
      document: editContext.document,
      getDocumentLayout: () => editContext.documentLayout,
      selectionChanges: editContext.composer.selectionChanges,
      selectionNotifier: editContext.composer.selectionNotifier,
      contentTapHandler: _contentTapDelegate,
      autoScroller: _autoScrollController,
      showDebugPaint: widget.debugPaint.gestures,
    );
  }

  Widget _buildAndroidGestureSystem() {
    return AndroidDocumentTouchInteractor(
      focusNode: _focusNode,
      editor: editContext.editor,
      document: editContext.document,
      getDocumentLayout: () => editContext.documentLayout,
      selection: editContext.composer.selectionNotifier,
      contentTapHandler: _contentTapDelegate,
      scrollController: _scrollController,
      documentKey: _docLayoutKey,
      documentLayoutLink: _documentLayoutLink,
      selectionLinks: _selectionLinks,
      handleColor: widget.androidHandleColor ?? Theme.of(context).primaryColor,
      popoverToolbarBuilder: widget.androidToolbarBuilder ?? (_) => const SizedBox(),
      createOverlayControlsClipper: widget.createOverlayControlsClipper,
      overlayController: widget.overlayController,
      showDebugPaint: widget.debugPaint.gestures,
    );
  }

  Widget _buildIOSGestureSystem() {
    return IOSDocumentTouchInteractor(
      focusNode: _focusNode,
      editor: editContext.editor,
      document: editContext.document,
      getDocumentLayout: () => editContext.documentLayout,
      selection: editContext.composer.selectionNotifier,
      contentTapHandler: _contentTapDelegate,
      scrollController: _scrollController,
      documentKey: _docLayoutKey,
      documentLayoutLink: _documentLayoutLink,
      selectionLinks: _selectionLinks,
      handleColor: widget.iOSHandleColor ?? Theme.of(context).primaryColor,
      popoverToolbarBuilder: widget.iOSToolbarBuilder ?? (_) => const SizedBox(),
      floatingCursorController: _floatingCursorController,
      createOverlayControlsClipper: widget.createOverlayControlsClipper,
      overlayController: widget.overlayController,
      showDebugPaint: widget.debugPaint.gestures,
    );
  }
}

/// A [SuperEditorLayerBuilder] that builds a [SelectionLeadersDocumentLayer], which positions
/// leader widgets at the base and extent of the user's selection, so that other widgets
/// can position themselves relative to the user's selection.
class _SelectionLeadersDocumentLayerBuilder implements SuperEditorLayerBuilder {
  const _SelectionLeadersDocumentLayerBuilder({
    required this.links,
    // ignore: unused_element
    this.showDebugLeaderBounds = false,
  });

  /// Collections of [LayerLink]s, which are given to leader widgets that are
  /// positioned at the selection bounds, and around the full selection.
  final SelectionLayerLinks links;

  /// Whether to paint colorful bounds around the leader widgets, for debugging purposes.
  final bool showDebugLeaderBounds;

  @override
  Widget build(BuildContext context, SuperEditorContext editContext) {
    return SelectionLeadersDocumentLayer(
      document: editContext.document,
      selection: editContext.composer.selectionNotifier,
      documentLayoutResolver: () => editContext.documentLayout,
      links: links,
      showDebugLeaderBounds: showDebugLeaderBounds,
    );
  }
}

/// A [SuperEditor] plugin.
///
/// A [SuperEditorPlugin] can be thought of as a combination of two plugins.
///
/// First, there's the part that extends the behavior of an [Editor]. Those extensions
/// are added in [attach].
///
/// Second, there's the part that extends the behavior of a [SuperEditor] widget, directly.
/// Those behaviors are collected through various properties, such as [keyboardActions] and
/// [componentBuilders].
///
/// An [Editor] is a logical pipeline of requests, commands, and reactions. It has no direct
/// connection to a user interface. A [SuperEditor] widget is a complete editor user interface.
/// When a plugin is given to a [SuperEditor] widget, the [SuperEditor] widget [attach]s the
/// plugin to its [Editor], and then the [SuperEditor] widget pulls out UI related behaviors
/// from the plugin for things like keyboard handlers and component builders.
///
/// [Editor] extensions are applied differently than the [SuperEditor] UI extensions, because
/// an [Editor] is mutable, meaning it can be altered. But a [SuperEditor] widget, like all other
/// widgets, is immutable, and must be rebuilt when properties change. As a result, each plugin
/// is instructed to alter an [Editor] as desired, but [SuperEditor] UI extensions are queried
/// from the plugin, so that the [SuperEditor] widget can pass those extensions as properties
/// during a widget build.
abstract class SuperEditorPlugin {
  /// Adds desired behaviors to the given [editor].
  void attach(Editor editor) {}

  /// Removes behaviors from the given [editor], which were added in [attach].
  void detach(Editor editor) {}

  /// Additional [DocumentKeyboardAction]s that will be added to a given [SuperEditor] widget.
  List<DocumentKeyboardAction> get keyboardActions => [];

  /// Additional [ComponentBuilder]s that will be added to a given [SuperEditor] widget.
  List<ComponentBuilder> get componentBuilders => [];
}

/// A collection of policies that dictate how a [SuperEditor]'s selection will change
/// based on other behaviors, such as focus changes.
class SuperEditorSelectionPolicies {
  const SuperEditorSelectionPolicies({
    this.placeCaretAtEndOfDocumentOnGainFocus = true,
    this.restorePreviousSelectionOnGainFocus = true,
    this.clearSelectionWhenEditorLosesFocus = true,
    this.clearSelectionWhenImeConnectionCloses = true,
  });

  /// Whether the editor should automatically place the caret at the end of the document,
  /// if the editor receives focus without an existing selection.
  ///
  /// [restorePreviousSelectionOnGainFocus] takes priority over this policy.
  final bool placeCaretAtEndOfDocumentOnGainFocus;

  /// Whether the editor's previous selection should be restored when the editor re-gains
  /// focus, after having previous lost focus.
  final bool restorePreviousSelectionOnGainFocus;

  /// Whether the editor's selection should be removed when the editor loses
  /// all focus (not just primary focus).
  ///
  /// If `true`, when focus moves to a different subtree, such as a popup text
  /// field, or a button somewhere else on the screen, the editor will remove
  /// its selection. When focus returns to the editor, the previous selection can
  /// be restored, but that's controlled by other policies.
  ///
  /// If `false`, the editor will retain its selection, including a visual caret
  /// and selected content, even when the editor doesn't have any focus, and can't
  /// process any input.
  final bool clearSelectionWhenEditorLosesFocus;

  /// Whether the editor's selection should be removed when the editor closes or loses
  /// its IME connection.
  ///
  /// Defaults to `true`.
  ///
  /// Apps that include a custom input mode, such as an editing panel that sometimes
  /// replaces the software keyboard, should set this to `false` and instead control the
  /// IME connection manually.
  final bool clearSelectionWhenImeConnectionCloses;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SuperEditorSelectionPolicies &&
          runtimeType == other.runtimeType &&
          placeCaretAtEndOfDocumentOnGainFocus == other.placeCaretAtEndOfDocumentOnGainFocus &&
          restorePreviousSelectionOnGainFocus == other.restorePreviousSelectionOnGainFocus &&
          clearSelectionWhenEditorLosesFocus == other.clearSelectionWhenEditorLosesFocus &&
          clearSelectionWhenImeConnectionCloses == other.clearSelectionWhenImeConnectionCloses;

  @override
  int get hashCode =>
      placeCaretAtEndOfDocumentOnGainFocus.hashCode ^
      restorePreviousSelectionOnGainFocus.hashCode ^
      clearSelectionWhenEditorLosesFocus.hashCode ^
      clearSelectionWhenImeConnectionCloses.hashCode;
}

/// Builds widgets that are displayed at the same position and size as
/// the document layout within a [SuperEditor].
abstract class SuperEditorLayerBuilder {
  Widget build(BuildContext context, SuperEditorContext editContext);
}

/// A [SuperEditorLayerBuilder] that's implemented with a given function, so
/// that simple use-cases don't need to sub-class [SuperEditorLayerBuilder].
class FunctionalSuperEditorLayerBuilder implements SuperEditorLayerBuilder {
  const FunctionalSuperEditorLayerBuilder(this._delegate);

  final Widget Function(BuildContext context, SuperEditorContext editContext) _delegate;

  @override
  Widget build(BuildContext context, SuperEditorContext editContext) => _delegate(context, editContext);
}

/// A [SuperEditorLayerBuilder] that paints a caret at the primary selection extent
/// in a [SuperEditor].
class DefaultCaretOverlayBuilder implements SuperEditorLayerBuilder {
  const DefaultCaretOverlayBuilder({
    this.caretStyle = const CaretStyle(
      width: 2,
      color: Colors.black,
    ),
    this.platformOverride,
    this.displayOnAllPlatforms = false,
    this.blinkTimingMode = BlinkTimingMode.ticker,
  });

  /// Styles applied to the caret that's painted by this caret overlay.
  final CaretStyle caretStyle;

  /// The platform to use to determine caret behavior, defaults to [defaultTargetPlatform].
  final TargetPlatform? platformOverride;

  /// Whether to display a caret on all platforms, including mobile.
  ///
  /// By default, the caret is only displayed on desktop.
  final bool displayOnAllPlatforms;

  /// The timing mechanism used to blink, e.g., `Ticker` or `Timer`.
  ///
  /// `Timer`s are not expected to work in tests.
  final BlinkTimingMode blinkTimingMode;

  @override
  Widget build(BuildContext context, SuperEditorContext editContext) {
    // By default, don't show a caret on mobile because SuperEditor displays
    // mobile carets and handles elsewhere. This can be overridden by settings
    // `displayOnAllPlatforms` to true.
    final platform = platformOverride ?? defaultTargetPlatform;
    if (!displayOnAllPlatforms && (platform == TargetPlatform.android || platform == TargetPlatform.iOS)) {
      return const SizedBox();
    }

    return IgnorePointer(
      // ^ ignore pointer so that user gestures fall through to the document gesture
      //   system, which sits beneath the document.
      child: CaretDocumentOverlay(
        composer: editContext.composer,
        documentLayoutResolver: () => editContext.documentLayout,
        caretStyle: caretStyle,
        blinkTimingMode: blinkTimingMode,
      ),
    );
  }
}

/// Creates visual components for the standard [SuperEditor].
///
/// These builders are in priority order. The first builder
/// to return a non-null component is used.
final defaultComponentBuilders = <ComponentBuilder>[
  const BlockquoteComponentBuilder(),
  const ParagraphComponentBuilder(),
  const ListItemComponentBuilder(),
  const ImageComponentBuilder(),
  const HorizontalRuleComponentBuilder(),
];

/// Keyboard actions for the standard [SuperEditor].
final defaultKeyboardActions = <DocumentKeyboardAction>[
  toggleInteractionModeWhenCmdOrCtrlPressed,
  doNothingWhenThereIsNoSelection,
  scrollOnPageUpKeyPress,
  scrollOnPageDownKeyPress,
  scrollOnCtrlOrCmdAndHomeKeyPress,
  scrollOnCtrlOrCmdAndEndKeyPress,
  pasteWhenCmdVIsPressed,
  copyWhenCmdCIsPressed,
  cutWhenCmdXIsPressed,
  collapseSelectionWhenEscIsPressed,
  selectAllWhenCmdAIsPressed,
  moveLeftAndRightWithArrowKeys,
  moveUpAndDownWithArrowKeys,
  moveToLineStartWithHome,
  moveToLineEndWithEnd,
  tabToIndentListItem,
  shiftTabToUnIndentListItem,
  backspaceToUnIndentListItem,
  backspaceToConvertTaskToParagraph,
  backspaceToClearParagraphBlockType,
  cmdBToToggleBold,
  cmdIToToggleItalics,
  shiftEnterToInsertNewlineInBlock,
  enterToInsertNewTask,
  enterToInsertBlockNewline,
  moveToLineStartOrEndWithCtrlAOrE,
  deleteToStartOfLineWithCmdBackspaceOnMac,
  deleteWordUpstreamWithAltBackspaceOnMac,
  deleteWordUpstreamWithControlBackspaceOnWindowsAndLinux,
  deleteUpstreamContentWithBackspace,
  deleteToEndOfLineWithCmdDeleteOnMac,
  deleteWordDownstreamWithAltDeleteOnMac,
  deleteWordDownstreamWithControlDeleteOnWindowsAndLinux,
  deleteDownstreamContentWithDelete,
  blockControlKeys,
  anyCharacterOrDestructiveKeyToDeleteSelection,
  anyCharacterToInsertInParagraph,
  anyCharacterToInsertInTextContent,
];

/// Keyboard actions for a [SuperEditor] running with IME on
/// desktop.
///
/// Using the IME on desktop involves partial input from the IME
/// and partial input from non-content keys, like arrow keys.
final defaultImeKeyboardActions = <DocumentKeyboardAction>[
  toggleInteractionModeWhenCmdOrCtrlPressed,
  pasteWhenCmdVIsPressed,
  copyWhenCmdCIsPressed,
  cutWhenCmdXIsPressed,
  selectAllWhenCmdAIsPressed,
  cmdBToToggleBold,
  cmdIToToggleItalics,
  doNothingWithBackspaceOnWeb,
  backspaceToConvertTaskToParagraph,
  backspaceToUnIndentListItem,
  backspaceToClearParagraphBlockType,
  deleteDownstreamCharacterWithCtrlDeleteOnMac,
  scrollOnCtrlOrCmdAndHomeKeyPress,
  scrollOnCtrlOrCmdAndEndKeyPress,
  doNothinOnMac,
  doNothingWhenThereIsNoSelection,
  scrollOnPageUpKeyPress,
  scrollOnPageDownKeyPress,
  moveUpAndDownWithArrowKeys,
  doNothingWithLeftRightArrowKeysAtMiddleOfTextOnWeb,
  moveLeftAndRightWithArrowKeys,
  moveToLineStartWithHome,
  moveToLineEndWithEnd,
  doNothingWithEnterOnWeb,
  enterToInsertNewTask,
  enterToInsertBlockNewline,
  tabToIndentListItem,
  shiftTabToUnIndentListItem,
  shiftEnterToInsertNewlineInBlock,
  deleteToStartOfLineWithCmdBackspaceOnMac,
  deleteWordUpstreamWithAltBackspaceOnMac,
  deleteWordUpstreamWithControlBackspaceOnWindowsAndLinux,
  deleteUpstreamContentWithBackspace,
  deleteToEndOfLineWithCmdDeleteOnMac,
  deleteWordDownstreamWithAltDeleteOnMac,
  deleteWordDownstreamWithControlDeleteOnWindowsAndLinux,
  doNothingWithDeleteOnWeb,
  deleteDownstreamContentWithDelete,
];

/// Stylesheet applied to all [SuperEditor]s by default.
final defaultStylesheet = Stylesheet(
  rules: [
    StyleRule(
      BlockSelector.all,
      (doc, docNode) {
        return {
          "maxWidth": 640.0,
          "padding": const CascadingPadding.symmetric(horizontal: 24),
          "textStyle": const TextStyle(
            color: Colors.black,
            fontSize: 18,
            height: 1.4,
          ),
        };
      },
    ),
    StyleRule(
      const BlockSelector("header1"),
      (doc, docNode) {
        return {
          "padding": const CascadingPadding.only(top: 40),
          "textStyle": const TextStyle(
            color: Color(0xFF333333),
            fontSize: 38,
            fontWeight: FontWeight.bold,
          ),
        };
      },
    ),
    StyleRule(
      const BlockSelector("header2"),
      (doc, docNode) {
        return {
          "padding": const CascadingPadding.only(top: 32),
          "textStyle": const TextStyle(
            color: Color(0xFF333333),
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        };
      },
    ),
    StyleRule(
      const BlockSelector("header3"),
      (doc, docNode) {
        return {
          "padding": const CascadingPadding.only(top: 28),
          "textStyle": const TextStyle(
            color: Color(0xFF333333),
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        };
      },
    ),
    StyleRule(
      const BlockSelector("paragraph"),
      (doc, docNode) {
        return {
          "padding": const CascadingPadding.only(top: 24),
        };
      },
    ),
    StyleRule(
      const BlockSelector("paragraph").after("header1"),
      (doc, docNode) {
        return {
          "padding": const CascadingPadding.only(top: 0),
        };
      },
    ),
    StyleRule(
      const BlockSelector("paragraph").after("header2"),
      (doc, docNode) {
        return {
          "padding": const CascadingPadding.only(top: 0),
        };
      },
    ),
    StyleRule(
      const BlockSelector("paragraph").after("header3"),
      (doc, docNode) {
        return {
          "padding": const CascadingPadding.only(top: 0),
        };
      },
    ),
    StyleRule(
      const BlockSelector("listItem"),
      (doc, docNode) {
        return {
          "padding": const CascadingPadding.only(top: 24),
        };
      },
    ),
    StyleRule(
      const BlockSelector("blockquote"),
      (doc, docNode) {
        return {
          "textStyle": const TextStyle(
            color: Colors.grey,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            height: 1.4,
          ),
        };
      },
    ),
    StyleRule(
      BlockSelector.all.last(),
      (doc, docNode) {
        return {
          "padding": const CascadingPadding.only(bottom: 96),
        };
      },
    ),
  ],
  inlineTextStyler: defaultInlineTextStyler,
);

TextStyle defaultInlineTextStyler(Set<Attribution> attributions, TextStyle existingStyle) {
  return existingStyle.merge(defaultStyleBuilder(attributions));
}

/// Creates [TextStyles] for the standard [SuperEditor].
TextStyle defaultStyleBuilder(Set<Attribution> attributions) {
  TextStyle newStyle = const TextStyle();

  for (final attribution in attributions) {
    if (attribution == boldAttribution) {
      newStyle = newStyle.copyWith(
        fontWeight: FontWeight.bold,
      );
    } else if (attribution == italicsAttribution) {
      newStyle = newStyle.copyWith(
        fontStyle: FontStyle.italic,
      );
    } else if (attribution == underlineAttribution) {
      newStyle = newStyle.copyWith(
        decoration: newStyle.decoration == null
            ? TextDecoration.underline
            : TextDecoration.combine([TextDecoration.underline, newStyle.decoration!]),
      );
    } else if (attribution == strikethroughAttribution) {
      newStyle = newStyle.copyWith(
        decoration: newStyle.decoration == null
            ? TextDecoration.lineThrough
            : TextDecoration.combine([TextDecoration.lineThrough, newStyle.decoration!]),
      );
    } else if (attribution is LinkAttribution) {
      newStyle = newStyle.copyWith(
        color: Colors.lightBlue,
        decoration: TextDecoration.underline,
      );
    }
  }
  return newStyle;
}

/// Default visual styles related to content selection.
const defaultSelectionStyle = SelectionStyles(
  selectionColor: Color(0xFFACCEF7),
);

typedef SuperEditorContentTapDelegateFactory = ContentTapDelegate Function(SuperEditorContext editContext);

SuperEditorLaunchLinkTapHandler superEditorLaunchLinkTapHandlerFactory(SuperEditorContext editContext) =>
    SuperEditorLaunchLinkTapHandler(editContext.document, editContext.composer);

/// A [ContentTapDelegate] that opens links when the user taps text with
/// a [LinkAttribution].
///
/// This delegate only opens links when [composer.isInInteractionMode] is
/// `true`.
class SuperEditorLaunchLinkTapHandler extends ContentTapDelegate {
  SuperEditorLaunchLinkTapHandler(this.document, this.composer) {
    composer.isInInteractionMode.addListener(notifyListeners);
  }

  @override
  void dispose() {
    composer.isInInteractionMode.removeListener(notifyListeners);
    super.dispose();
  }

  final Document document;
  final DocumentComposer composer;

  @override
  MouseCursor? mouseCursorForContentHover(DocumentPosition hoverPosition) {
    if (!composer.isInInteractionMode.value) {
      // The editor isn't in "interaction mode". We don't want a special cursor
      return null;
    }

    final link = _getLinkAtPosition(hoverPosition);
    return link != null ? SystemMouseCursors.click : null;
  }

  @override
  TapHandlingInstruction onTap(DocumentPosition tapPosition) {
    if (!composer.isInInteractionMode.value) {
      // The editor isn't in "interaction mode". We don't want to allow
      // users to open links by tapping on them.
      return TapHandlingInstruction.continueHandling;
    }

    final link = _getLinkAtPosition(tapPosition);
    if (link != null) {
      // The user tapped on a link. Launch it.
      UrlLauncher.instance.launchUrl(link);
      return TapHandlingInstruction.halt;
    } else {
      // The user didn't tap on a link.
      return TapHandlingInstruction.continueHandling;
    }
  }

  Uri? _getLinkAtPosition(DocumentPosition position) {
    final nodePosition = position.nodePosition;
    if (nodePosition is! TextNodePosition) {
      return null;
    }

    final textNode = document.getNodeById(position.nodeId);
    if (textNode is! TextNode) {
      editorGesturesLog
          .shout("Received a report of a tap on a TextNodePosition, but the node with that ID is a: $textNode");
      return null;
    }

    final tappedAttributions = textNode.text.getAllAttributionsAt(nodePosition.offset);
    for (final tappedAttribution in tappedAttributions) {
      if (tappedAttribution is LinkAttribution) {
        return tappedAttribution.url;
      }
    }

    return null;
  }
}
