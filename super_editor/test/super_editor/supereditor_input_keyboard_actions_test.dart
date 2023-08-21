import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';

import '../test_tools.dart';
import '../test_tools_user_input.dart';
import 'supereditor_test_tools.dart';
import 'test_documents.dart';

void main() {
  group('Super Editor keyboard actions', () {
    group("movement >", () {
      group("Mac >", () {
        group("jumps to", () {
          testWidgetsOnMac('beginning of line with CMD + LEFT ARROW', (tester) async {
            // Start the user's selection somewhere after the beginning of the first
            // line in the first node.
            await _pumpCaretMovementTestSetup(tester, textOffsetInFirstNode: 8);

            await tester.pressCmdLeftArrow();

            // Ensure that the caret moved to the beginning of the line.
            expect(
              SuperEditorInspector.findDocumentSelection(),
              const DocumentSelection.collapsed(
                position: DocumentPosition(
                  nodeId: "1",
                  nodePosition: TextNodePosition(offset: 0),
                ),
              ),
            );
          });

          testWidgetsOnMac('end of line with CMD + RIGHT ARROW', (tester) async {
            // Start the user's selection somewhere before the end of the first line
            // in the first node.
            await _pumpCaretMovementTestSetup(tester, textOffsetInFirstNode: 8);

            await tester.pressCmdRightArrow();

            // Ensure that the caret moved to the end of the line. This value
            // is very fragile. If the text size or layout width changes, this value
            // will also need to change.
            expect(
              SuperEditorInspector.findDocumentSelection(),
              const DocumentSelection.collapsed(
                position: DocumentPosition(
                  nodeId: "1",
                  nodePosition: TextNodePosition(offset: 27),
                ),
              ),
            );
          });

          testWidgetsOnMac('beginning of word with ALT + LEFT ARROW', (tester) async {
            // Start the user's selection somewhere in the middle of a word.
            await _pumpCaretMovementTestSetup(tester, textOffsetInFirstNode: 8);

            await tester.pressAltLeftArrow();

            // Ensure that the caret moved to the beginning of the word.
            expect(
              SuperEditorInspector.findDocumentSelection(),
              const DocumentSelection.collapsed(
                position: DocumentPosition(
                  nodeId: "1",
                  nodePosition: TextNodePosition(offset: 6),
                ),
              ),
            );
          });

          testWidgetsOnMac('end of word with ALT + RIGHT ARROW', (tester) async {
            // Start the user's selection somewhere in the middle of a word.
            await _pumpCaretMovementTestSetup(tester, textOffsetInFirstNode: 8);

            await tester.pressAltRightArrow();

            // Ensure that the caret moved to the beginning of the word.
            expect(
              SuperEditorInspector.findDocumentSelection(),
              const DocumentSelection.collapsed(
                position: DocumentPosition(
                  nodeId: "1",
                  nodePosition: TextNodePosition(offset: 11),
                ),
              ),
            );
          });
        });

        testWidgetsOnMac("option + backspace: deletes a word upstream", (tester) async {
          final testContext = await tester
              .createDocument() //
              .withSingleParagraph()
              .withInputSource(inputSourceVariant.currentValue!)
              .pump();

          // Lorem ipsum| dolor sit amet...
          await tester.placeCaretInParagraph("1", 11);

          // Press option + backspace
          await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
          await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
          await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);

          // Ensure that the whole word was deleted.
          final paragraphNode = testContext.findEditContext().document.nodes.first as ParagraphNode;
          expect(paragraphNode.text.text.startsWith("Lorem  dolor sit amet"), isTrue);
          expect(
            SuperEditorInspector.findDocumentSelection(),
            const DocumentSelection.collapsed(
              position: DocumentPosition(
                nodeId: "1",
                nodePosition: TextNodePosition(offset: 6),
              ),
            ),
          );
        }, variant: inputSourceVariant);

        testWidgetsOnMac("option + backspace: deletes a word upstream (after a space)", (tester) async {
          final testContext = await tester
              .createDocument() //
              .withSingleParagraph()
              .withInputSource(inputSourceVariant.currentValue!)
              .pump();

          // Lorem ipsum |dolor sit amet...
          await tester.placeCaretInParagraph("1", 12);

          // Press option + backspace
          await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
          await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
          await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);

          // Ensure that the whole word was deleted.
          final paragraphNode = testContext.findEditContext().document.nodes.first as ParagraphNode;
          expect(paragraphNode.text.text.startsWith("Lorem dolor sit amet"), isTrue);
          expect(
            SuperEditorInspector.findDocumentSelection(),
            const DocumentSelection.collapsed(
              position: DocumentPosition(
                nodeId: "1",
                nodePosition: TextNodePosition(offset: 6),
              ),
            ),
          );
        }, variant: inputSourceVariant);

        testWidgetsOnMac("option + delete: deletes a word downstream", (tester) async {
          final testContext = await tester
              .createDocument() //
              .withSingleParagraph()
              .withInputSource(inputSourceVariant.currentValue!)
              .pump();

          // Lorem ipsum |dolor sit amet...
          await tester.placeCaretInParagraph("1", 12);

          // Press option + delete
          await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
          await tester.sendKeyEvent(LogicalKeyboardKey.delete);
          await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);

          // Ensure that the whole word was deleted.
          final paragraphNode = testContext.findEditContext().document.nodes.first as ParagraphNode;
          expect(paragraphNode.text.text, startsWith("Lorem ipsum  sit amet"));
          expect(
            SuperEditorInspector.findDocumentSelection(),
            const DocumentSelection.collapsed(
              position: DocumentPosition(
                nodeId: "1",
                nodePosition: TextNodePosition(offset: 12),
              ),
            ),
          );
        }, variant: inputSourceVariant);

        testWidgetsOnMac("option + delete: deletes a word downstream (before a space)", (tester) async {
          final testContext = await tester
              .createDocument() //
              .withSingleParagraph()
              .withInputSource(inputSourceVariant.currentValue!)
              .pump();

          // Lorem ipsum| dolor sit amet...
          await tester.placeCaretInParagraph("1", 11);

          // Press option + delete
          await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
          await tester.sendKeyEvent(LogicalKeyboardKey.delete);
          await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);

          // Ensure that the whole word was deleted.
          final paragraphNode = testContext.findEditContext().document.nodes.first as ParagraphNode;
          expect(paragraphNode.text.text.startsWith("Lorem ipsum sit amet"), isTrue);
          expect(
            SuperEditorInspector.findDocumentSelection(),
            const DocumentSelection.collapsed(
              position: DocumentPosition(
                nodeId: "1",
                nodePosition: TextNodePosition(offset: 11),
              ),
            ),
          );
        }, variant: inputSourceVariant);

        testWidgetsOnMac("control + backspace: deletes a single upstream character", (tester) async {
          final testContext = await tester
              .createDocument() //
              .withSingleParagraph()
              .withInputSource(inputSourceVariant.currentValue!)
              .pump();

          // Lorem ipsum| dolor sit amet...
          await tester.placeCaretInParagraph("1", 11);

          // Press control + backspace
          await tester.pressCtlBackspace();
          // Simulate the OS generating a performSelector call.
          // TODO: remove after https://github.com/flutter/flutter/issues/132917 is solved.
          await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
            SystemChannels.textInput.name,
            SystemChannels.textInput.codec.encodeMethodCall(
              const MethodCall('TextInputClient.performSelectors', <dynamic>[
                -1,
                [MacOsSelectors.deleteBackwardByDecomposingPreviousCharacter]
              ]),
            ),
            (ByteData? data) {},
          );

          // Ensure that a character was deleted.
          final paragraphNode = testContext.findEditContext().document.nodes.first as ParagraphNode;
          expect(paragraphNode.text.text.startsWith("Lorem ipsu dolor sit amet"), isTrue);
          expect(
            SuperEditorInspector.findDocumentSelection(),
            const DocumentSelection.collapsed(
              position: DocumentPosition(
                nodeId: "1",
                nodePosition: TextNodePosition(offset: 10),
              ),
            ),
          );
        }, variant: inputSourceVariant);

        testWidgetsOnMac("control + delete: deletes a single downstream character", (tester) async {
          final testContext = await tester
              .createDocument() //
              .withSingleParagraph()
              .withInputSource(inputSourceVariant.currentValue!)
              .pump();

          // Lorem ipsum| dolor sit amet...
          await tester.placeCaretInParagraph("1", 11);

          // Press control + delete
          await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
          await tester.sendKeyEvent(LogicalKeyboardKey.delete);
          await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);

          // Ensure that a character was deleted.
          final paragraphNode = testContext.findEditContext().document.nodes.first as ParagraphNode;
          expect(paragraphNode.text.text.startsWith("Lorem ipsumdolor sit amet"), isTrue);
          expect(
            SuperEditorInspector.findDocumentSelection(),
            const DocumentSelection.collapsed(
              position: DocumentPosition(
                nodeId: "1",
                nodePosition: TextNodePosition(offset: 11),
              ),
            ),
          );
        }, variant: inputSourceVariant);
      });

      group("Windows and Linux >", () {
        group("jumps to", () {
          testWidgetsOnWindowsAndLinux('beginning of line with HOME in an auto-wrapping paragraph', (tester) async {
            await _pumpAutoWrappingTestSetup(tester);

            // Place caret at the second line at "adipiscing |elit"
            // We avoid placing the caret in the first line to make sure HOME doesn't move caret
            // all the way to the beginning of the text
            await tester.placeCaretInParagraph('1', 51);

            await tester.pressHome();

            // Ensure that the caret moved to the beginning of the wrapped line at "|adipiscing elit"
            expect(
              SuperEditorInspector.findDocumentSelection(),
              const DocumentSelection.collapsed(
                position: DocumentPosition(
                  nodeId: "1",
                  nodePosition: TextNodePosition(offset: 40),
                ),
              ),
            );
          });

          testWidgetsOnWindowsAndLinux('beginning of line with HOME in a paragraph with explicit new lines',
              (tester) async {
            await _pumpExplicitLineBreakTestSetup(tester);

            // Place caret at the second line at "consectetur adipiscing |elit"
            // We avoid placing the caret in the first line to make sure HOME doesn't move caret
            // all the way to the beginning of the text
            await tester.placeCaretInParagraph('1', 51);

            await tester.pressHome();

            // Ensure that the caret moved to the beginning of the second line at "|consectetur adipiscing elit"
            expect(
              SuperEditorInspector.findDocumentSelection(),
              const DocumentSelection.collapsed(
                position: DocumentPosition(
                  nodeId: "1",
                  nodePosition: TextNodePosition(offset: 27),
                ),
              ),
            );
          });

          testWidgetsOnWindowsAndLinux('end of line with END in an auto-wrapping paragraph', (tester) async {
            await _pumpAutoWrappingTestSetup(tester);

            // Place caret at the start of the first line
            // We avoid placing the caret in the last line to make sure END doesn't move caret
            // all the way to the end of the text
            await tester.placeCaretInParagraph('1', 0);

            await tester.pressEnd();

            // Ensure that the caret moved to the end of the line. This value
            // is very fragile. If the text size or layout width changes, this value
            // will also need to change.
            expect(
              SuperEditorInspector.findDocumentSelection(),
              const DocumentSelection.collapsed(
                position: DocumentPosition(
                  nodeId: "1",
                  nodePosition: TextNodePosition(offset: 17),
                ),
              ),
            );
          });

          testWidgetsOnWindowsAndLinux('end of line with END in a paragraph with explicit new lines', (tester) async {
            // Configure the screen to a size big enough so there's no auto line-wrapping
            await _pumpExplicitLineBreakTestSetup(tester, size: const Size(1024, 400));

            // Place caret at the first line at "Lorem |ipsum"
            // Avoid placing caret in the last line to make sure END doesn't move caret
            // all the way to the end of the text
            await tester.placeCaretInParagraph('1', 6);

            await tester.pressEnd();

            // Ensure that the caret moved the end of the first line
            expect(
              SuperEditorInspector.findDocumentSelection(),
              const DocumentSelection.collapsed(
                position: DocumentPosition(
                  nodeId: "1",
                  nodePosition: TextNodePosition(offset: 26, affinity: TextAffinity.upstream),
                ),
              ),
            );
          });

          testWidgetsOnWindowsAndLinux('beginning of word with CTRL + LEFT ARROW', (tester) async {
            // Start the user's selection somewhere in the middle of a word.
            await _pumpCaretMovementTestSetup(tester, textOffsetInFirstNode: 8);

            await tester.pressCtlLeftArrow();

            // Ensure that the caret moved to the beginning of the word.
            expect(
              SuperEditorInspector.findDocumentSelection(),
              const DocumentSelection.collapsed(
                position: DocumentPosition(
                  nodeId: "1",
                  nodePosition: TextNodePosition(offset: 6),
                ),
              ),
            );
          });

          testWidgetsOnWindowsAndLinux('end of word with CTRL + RIGHT ARROW', (tester) async {
            // Start the user's selection somewhere in the middle of a word.
            await _pumpCaretMovementTestSetup(tester, textOffsetInFirstNode: 8);

            await tester.pressCtlRightArrow();

            // Ensure that the caret moved to the beginning of the word.
            expect(
              SuperEditorInspector.findDocumentSelection(),
              const DocumentSelection.collapsed(
                position: DocumentPosition(
                  nodeId: "1",
                  nodePosition: TextNodePosition(offset: 11),
                ),
              ),
            );
          });
        });

        testWidgetsOnWindowsAndLinux("control + backspace: deletes a word upstream", (tester) async {
          final testContext = await tester
              .createDocument() //
              .withSingleParagraph()
              .withInputSource(inputSourceVariant.currentValue!)
              .pump();

          // Lorem ipsum| dolor sit amet...
          await tester.placeCaretInParagraph("1", 11);

          // Press control + backspace
          await tester.pressCtlBackspace();

          // Ensure that the whole word was deleted.
          final paragraphNode = testContext.findEditContext().document.nodes.first as ParagraphNode;
          expect(paragraphNode.text.text.startsWith("Lorem  dolor sit amet"), isTrue);
          expect(
            SuperEditorInspector.findDocumentSelection(),
            const DocumentSelection.collapsed(
              position: DocumentPosition(
                nodeId: "1",
                nodePosition: TextNodePosition(offset: 6),
              ),
            ),
          );
        }, variant: inputSourceVariant);

        testWidgetsOnWindowsAndLinux("control + backspace: deletes a word upstream (after a space)", (tester) async {
          final testContext = await tester
              .createDocument() //
              .withSingleParagraph()
              .withInputSource(inputSourceVariant.currentValue!)
              .pump();

          // Lorem ipsum |dolor sit amet...
          await tester.placeCaretInParagraph("1", 12);

          // Press control + backspace
          await tester.pressCtlBackspace();

          // Ensure that the whole word was deleted.
          final paragraphNode = testContext.findEditContext().document.nodes.first as ParagraphNode;
          expect(paragraphNode.text.text.startsWith("Lorem dolor sit amet"), isTrue);
          expect(
            SuperEditorInspector.findDocumentSelection(),
            const DocumentSelection.collapsed(
              position: DocumentPosition(
                nodeId: "1",
                nodePosition: TextNodePosition(offset: 6),
              ),
            ),
          );
        }, variant: inputSourceVariant);

        testWidgetsOnWindowsAndLinux("control + delete: deletes a word downstream", (tester) async {
          final testContext = await tester
              .createDocument() //
              .withSingleParagraph()
              .withInputSource(inputSourceVariant.currentValue!)
              .pump();

          // Lorem ipsum |dolor sit amet...
          await tester.placeCaretInParagraph("1", 12);

          // Press control + delete
          await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
          await tester.sendKeyEvent(LogicalKeyboardKey.delete);
          await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);

          // Ensure that the whole word was deleted.
          final paragraphNode = testContext.findEditContext().document.nodes.first as ParagraphNode;
          expect(paragraphNode.text.text, startsWith("Lorem ipsum  sit amet"));
          expect(
            SuperEditorInspector.findDocumentSelection(),
            const DocumentSelection.collapsed(
              position: DocumentPosition(
                nodeId: "1",
                nodePosition: TextNodePosition(offset: 12),
              ),
            ),
          );
        }, variant: inputSourceVariant);

        testWidgetsOnWindowsAndLinux("control + backspace: deletes a word downstream (before a space)", (tester) async {
          final testContext = await tester
              .createDocument() //
              .withSingleParagraph()
              .withInputSource(inputSourceVariant.currentValue!)
              .pump();

          // Lorem ipsum| dolor sit amet...
          await tester.placeCaretInParagraph("1", 11);

          // Press control + delete
          await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
          await tester.sendKeyEvent(LogicalKeyboardKey.delete);
          await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);

          // Ensure that the whole word was deleted.
          final paragraphNode = testContext.findEditContext().document.nodes.first as ParagraphNode;
          expect(paragraphNode.text.text.startsWith("Lorem ipsum sit amet"), isTrue);
          expect(
            SuperEditorInspector.findDocumentSelection(),
            const DocumentSelection.collapsed(
              position: DocumentPosition(
                nodeId: "1",
                nodePosition: TextNodePosition(offset: 11),
              ),
            ),
          );
        }, variant: inputSourceVariant);

        testWidgetsOnWindowsAndLinux("alt + backspace: deletes upstream character", (tester) async {
          final testContext = await tester
              .createDocument() //
              .withSingleParagraph()
              .withInputSource(inputSourceVariant.currentValue!)
              .pump();

          // Lorem ipsum| dolor sit amet...
          await tester.placeCaretInParagraph("1", 11);

          // Press alt + backspace
          await tester.pressAltBackspace();

          // Ensure that nothing changed.
          final paragraphNode = testContext.findEditContext().document.nodes.first as ParagraphNode;
          expect(paragraphNode.text.text, startsWith("Lorem ipsu dolor sit amet"));
          expect(
            SuperEditorInspector.findDocumentSelection(),
            const DocumentSelection.collapsed(
              position: DocumentPosition(
                nodeId: "1",
                nodePosition: TextNodePosition(offset: 10),
              ),
            ),
          );
        }, variant: inputSourceVariant);

        testWidgetsOnWindowsAndLinux("alt + delete: deletes downstream character", (tester) async {
          final testContext = await tester
              .createDocument() //
              .withSingleParagraph()
              .withInputSource(inputSourceVariant.currentValue!)
              .pump();

          // Lorem ipsum| dolor sit amet...
          await tester.placeCaretInParagraph("1", 11);

          // Press alt + delete
          await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
          await tester.sendKeyEvent(LogicalKeyboardKey.delete);
          await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);

          // Ensure that nothing changed.
          final paragraphNode = testContext.findEditContext().document.nodes.first as ParagraphNode;
          expect(paragraphNode.text.text, startsWith("Lorem ipsumdolor sit amet"));
          expect(
            SuperEditorInspector.findDocumentSelection(),
            const DocumentSelection.collapsed(
              position: DocumentPosition(
                nodeId: "1",
                nodePosition: TextNodePosition(offset: 11),
              ),
            ),
          );
        }, variant: inputSourceVariant);
      });

      testWidgetsOnDesktop(
        "Backspace deletes upstream character and keeps paragraph metadata",
        (tester) async {
          final testContext = await tester
              .createDocument() //
              .fromMarkdown('# A header')
              .withInputSource(inputSourceVariant.currentValue!)
              .pump();

          final node = testContext.findEditContext().document.nodes.first;

          // Place caret at "A| header"
          await tester.placeCaretInParagraph(node.id, 1);

          // Delete "A".
          await tester.pressBackspace();

          // Ensure the first character was deleted.
          expect((node as TextNode).text.text, ' header');

          // Ensure the node is still a header.
          expect(node.getMetadataValue("blockType"), header1Attribution);
        },
        variant: inputSourceVariant,
      );

      testWidgetsOnDesktop(
        "Backspace clears metadata at start of a paragraph",
        (tester) async {
          final testContext = await tester
              .createDocument() //
              .fromMarkdown('# A header')
              .withInputSource(inputSourceVariant.currentValue!)
              .pump();

          final node = testContext.findEditContext().document.nodes.first;

          // Place caret at the start of the header.
          await tester.placeCaretInParagraph(node.id, 0);

          // Press backspace to clear the metadata.
          await tester.pressBackspace();

          // Ensure the text remains the same.
          expect((node as TextNode).text.text, 'A header');

          // Ensure the header was converted to a paragraph.
          expect(node.getMetadataValue("blockType"), paragraphAttribution);
        },
        variant: inputSourceVariant,
      );
    });

    group("Linux >", () {
      group('jumps to', () {
        testWidgetsOnLinux('preceding character with ALT + LEFT ARROW', (tester) async {
          // Start the user's selection somewhere in the middle of a word.
          await _pumpCaretMovementTestSetup(tester, textOffsetInFirstNode: 8);

          await tester.pressAltLeftArrow();

          // Ensure that the caret moved one character to the left.
          expect(
            SuperEditorInspector.findDocumentSelection(),
            const DocumentSelection.collapsed(
              position: DocumentPosition(
                nodeId: "1",
                nodePosition: TextNodePosition(offset: 7),
              ),
            ),
          );
        });

        testWidgetsOnLinux('next character with ALT + RIGHT ARROW', (tester) async {
          // Start the user's selection somewhere in the middle of a word.
          await _pumpCaretMovementTestSetup(tester, textOffsetInFirstNode: 8);

          await tester.pressAltRightArrow();

          // Ensure that the caret moved one character to the right
          expect(
            SuperEditorInspector.findDocumentSelection(),
            const DocumentSelection.collapsed(
              position: DocumentPosition(
                nodeId: "1",
                nodePosition: TextNodePosition(offset: 9),
              ),
            ),
          );
        });
      });
    });

    group("does nothing", () {
      testWidgetsOnWindows("with ALT + LEFT ARROW", (tester) async {
        // Start the user's selection somewhere in the middle of a word.
        await _pumpCaretMovementTestSetup(tester, textOffsetInFirstNode: 8);

        await tester.pressAltLeftArrow();

        // Ensure that the caret didn't move
        expect(
          SuperEditorInspector.findDocumentSelection(),
          const DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 8),
            ),
          ),
        );
      });

      testWidgetsOnWindows("with ALT + RIGHT ARROW", (tester) async {
        // Start the user's selection somewhere in the middle of a word.
        await _pumpCaretMovementTestSetup(tester, textOffsetInFirstNode: 8);

        await tester.pressAltRightArrow();

        // Ensure that the caret didn't move
        expect(
          SuperEditorInspector.findDocumentSelection(),
          const DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 8),
            ),
          ),
        );
      });

      testWidgetsOnWindowsAndLinux('with ALT + UP ARROW', (tester) async {
        await _pumpExplicitLineBreakTestSetup(tester);

        // Place caret at the second line at "consectetur adipiscing |elit"
        await tester.placeCaretInParagraph('1', 51);

        await tester.pressAltUpArrow();

        // Ensure that the caret didn't move
        expect(
          SuperEditorInspector.findDocumentSelection(),
          const DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 51),
            ),
          ),
        );
      });

      testWidgetsOnWindowsAndLinux('with ALT + DOWN ARROW', (tester) async {
        await _pumpExplicitLineBreakTestSetup(tester);

        // Place caret at the first line at "Lorem |ipsum"
        await tester.placeCaretInParagraph('1', 6);

        await tester.pressAltDownArrow();

        // Ensure that the caret didn't move
        expect(
          SuperEditorInspector.findDocumentSelection(),
          const DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 6),
            ),
          ),
        );
      });
    });

    group("shortcuts for Windows and Linux do nothing on mac", () {
      testWidgetsOnMac('HOME', (tester) async {
        // Start the user's selection somewhere after the beginning of the first
        // line in the first node.
        await _pumpCaretMovementTestSetup(tester, textOffsetInFirstNode: 8);

        await tester.pressHome();

        // Ensure that the caret didn't move
        expect(
          SuperEditorInspector.findDocumentSelection(),
          const DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 8),
            ),
          ),
        );
      });

      testWidgetsOnMac('END', (tester) async {
        // Start the user's selection somewhere after the beginning of the first
        // line in the first node.
        await _pumpCaretMovementTestSetup(tester, textOffsetInFirstNode: 2);

        await tester.pressEnd();

        // Ensure that the caret didn't move
        expect(
          SuperEditorInspector.findDocumentSelection(),
          const DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 2),
            ),
          ),
        );
      });

      testWidgetsOnMac('CTRL + LEFT ARROW', (tester) async {
        // Start the user's selection somewhere in the middle of a word.
        await _pumpCaretMovementTestSetup(tester, textOffsetInFirstNode: 8);

        await tester.pressCtlLeftArrow();

        // Ensure that the caret moved only one character to the left
        expect(
          SuperEditorInspector.findDocumentSelection(),
          const DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 7),
            ),
          ),
        );
      });

      testWidgetsOnMac('CTRL + RIGHT ARROW', (tester) async {
        // Start the user's selection somewhere in the middle of a word.
        await _pumpCaretMovementTestSetup(tester, textOffsetInFirstNode: 8);

        await tester.pressCtlRightArrow();

        // Ensure that the caret moved only one character to the right
        expect(
          SuperEditorInspector.findDocumentSelection(),
          const DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 9),
            ),
          ),
        );
      });
    });

    group("shortcuts for Mac do nothing on Windows and Linux", () {
      testWidgetsOnWindowsAndLinux('CMD + LEFT ARROW', (tester) async {
        // Start the user's selection somewhere after the beginning of the first
        // line in the first node.
        await _pumpCaretMovementTestSetup(tester, textOffsetInFirstNode: 8);

        await tester.pressCmdLeftArrow();

        // Ensure that the caret didn't move to the beginning of the line.
        expect(
          SuperEditorInspector.findDocumentSelection(),
          const DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 7),
            ),
          ),
        );
      });

      testWidgetsOnWindowsAndLinux('CMD + RIGHT ARROW', (tester) async {
        // Start the user's selection somewhere before the end of the first line
        // in the first node.
        await _pumpCaretMovementTestSetup(tester, textOffsetInFirstNode: 2);

        await tester.pressCmdRightArrow();

        // Ensure that the caret didn't move to the end of the line.
        expect(
          SuperEditorInspector.findDocumentSelection(),
          const DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 3),
            ),
          ),
        );
      });
    });

    group('CMD + A to select all', () {
      testWidgetsOnMac('does nothing when CMD key is pressed but A-key is not pressed', (tester) async {
        await tester //
            .createDocument()
            .withSingleParagraph()
            .pump();

        await tester.placeCaretInParagraph("1", 0);

        // Press CMD key.
        await tester.sendKeyEvent(LogicalKeyboardKey.metaLeft);

        // Ensure we didn't select all content.
        expect(
          SuperEditorInspector.findDocumentSelection(),
          const DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 0),
            ),
          ),
        );
      });

      testWidgetsOnMac('does nothing when A-key is pressed but meta key is not pressed', (tester) async {
        await tester //
            .createDocument()
            .withSingleParagraph()
            .pump();

        await tester.placeCaretInParagraph("1", 0);

        // Press CMD key.
        await tester.sendKeyEvent(LogicalKeyboardKey.keyA);

        // Ensure we didn't select all content.
        expect(
          SuperEditorInspector.findDocumentSelection(),
          const DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 1),
            ),
          ),
        );
      });

      testWidgetsOnMac('does nothing when CMD+A is pressed but the document is empty', (tester) async {
        await tester //
            .createDocument()
            .withSingleEmptyParagraph()
            .pump();

        await tester.placeCaretInParagraph("1", 0);

        await tester.pressCmdA();

        // We don't expect that our selection changed at all.
        expect(
          SuperEditorInspector.findDocumentSelection(),
          const DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 0),
            ),
          ),
        );
      });

      testWidgetsOnMac('selects all when CMD+A is pressed with a single-node document', (tester) async {
        await tester //
            .createDocument()
            .withCustomContent(MutableDocument(
              nodes: [
                ParagraphNode(
                  id: '1',
                  text: AttributedText('This is some text'),
                ),
              ],
            ))
            .pump();

        await tester.placeCaretInParagraph("1", 0);

        await tester.pressCmdA();

        // Ensure everything is selected.
        expect(
          SuperEditorInspector.findDocumentSelection(),
          const DocumentSelection(
            base: DocumentPosition(
              nodeId: '1',
              nodePosition: TextNodePosition(offset: 0),
            ),
            extent: DocumentPosition(
              nodeId: '1',
              nodePosition: TextNodePosition(offset: 17),
            ),
          ),
        );
      });

      testWidgetsOnMac('selects all when CMD+A is pressed with a two-node document', (tester) async {
        await tester //
            .createDocument()
            .withCustomContent(
              MutableDocument(
                nodes: [
                  ParagraphNode(
                    id: '1',
                    text: AttributedText('This is some text'),
                  ),
                  ParagraphNode(
                    id: '2',
                    text: AttributedText('This is some text'),
                  ),
                ],
              ),
            )
            .pump();

        await tester.placeCaretInParagraph("1", 0);

        await tester.pressCmdA();

        // Ensure everything is selected.
        expect(
          SuperEditorInspector.findDocumentSelection(),
          const DocumentSelection(
            base: DocumentPosition(
              nodeId: '1',
              nodePosition: TextNodePosition(offset: 0),
            ),
            extent: DocumentPosition(
              nodeId: '2',
              nodePosition: TextNodePosition(offset: 17),
            ),
          ),
        );
      });

      testWidgetsOnMac('selects all when CMD+A is pressed with a three-node document', (tester) async {
        await tester //
            .createDocument()
            .withCustomContent(
              MutableDocument(
                nodes: [
                  ImageNode(
                    id: '1',
                    imageUrl: 'https://fake.com/image/url.png',
                  ),
                  ParagraphNode(
                    id: '2',
                    text: AttributedText('This is some text'),
                  ),
                  ImageNode(
                    id: '3',
                    imageUrl: 'https://fake.com/image/url.png',
                  ),
                ],
              ),
            )
            .withAddedComponents([const FakeImageComponentBuilder(size: Size(800, 400))]) //
            .pump();

        await tester.placeCaretInParagraph("2", 0);

        await tester.pressCmdA();

        // Ensure everything is selected.
        expect(
          SuperEditorInspector.findDocumentSelection(),
          const DocumentSelection(
            base: DocumentPosition(
              nodeId: '1',
              nodePosition: UpstreamDownstreamNodePosition.upstream(),
            ),
            extent: DocumentPosition(
              nodeId: '3',
              nodePosition: UpstreamDownstreamNodePosition.downstream(),
            ),
          ),
        );
      });
    });

    group('key pressed with selection', () {
      testWidgetsOnMac('deletes selection if backspace is pressed', (tester) async {
        await tester //
            .createDocument()
            .withCustomContent(
              MutableDocument(
                nodes: [
                  ParagraphNode(
                    id: '1',
                    text: AttributedText('Text with [DELETEME] selection'),
                  ),
                ],
              ),
            )
            .pump();

        // Select "DELETEME" by doube-tapping.
        await tester.doubleTapInParagraph("1", 14);

        // Ensure that we selected the word.
        expect(
          SuperEditorInspector.findDocumentSelection(),
          const DocumentSelection(
            base: DocumentPosition(
              nodeId: '1',
              nodePosition: TextNodePosition(offset: 11),
            ),
            extent: DocumentPosition(
              nodeId: '1',
              nodePosition: TextNodePosition(offset: 19),
            ),
          ),
        );

        await tester.pressBackspace();

        // Ensure the selected content was deleted.
        expect(SuperEditorInspector.findTextInParagraph("1").text, "Text with [] selection");
        expect(
          SuperEditorInspector.findDocumentSelection(),
          const DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: '1',
              nodePosition: TextNodePosition(offset: 11),
            ),
          ),
        );
      });

      testWidgetsOnMac('deletes selection if delete is pressed', (tester) async {
        await tester //
            .createDocument()
            .withCustomContent(
              MutableDocument(
                nodes: [
                  ParagraphNode(
                    id: '1',
                    text: AttributedText('Text with [DELETEME] selection'),
                  ),
                ],
              ),
            )
            .pump();

        // Select "DELETEME" by doube-tapping.
        await tester.doubleTapInParagraph("1", 14);

        // Ensure that we selected the word.
        expect(
          SuperEditorInspector.findDocumentSelection(),
          const DocumentSelection(
            base: DocumentPosition(
              nodeId: '1',
              nodePosition: TextNodePosition(offset: 11),
            ),
            extent: DocumentPosition(
              nodeId: '1',
              nodePosition: TextNodePosition(offset: 19),
            ),
          ),
        );

        await tester.pressDelete();

        // Ensure the selected content was deleted.
        expect(SuperEditorInspector.findTextInParagraph("1").text, "Text with [] selection");
        expect(
          SuperEditorInspector.findDocumentSelection(),
          const DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: '1',
              nodePosition: TextNodePosition(offset: 11),
            ),
          ),
        );
      });

      testWidgetsOnMac('replaces selected content with character when character key is pressed', (tester) async {
        await tester //
            .createDocument()
            .withCustomContent(
              MutableDocument(
                nodes: [
                  ParagraphNode(
                    id: '1',
                    text: AttributedText('Text with [DELETEME] selection'),
                  ),
                ],
              ),
            )
            .withInputSource(TextInputSource.keyboard)
            .pump();

        // Select "DELETEME" by doube-tapping.
        await tester.doubleTapInParagraph("1", 14);

        // Ensure that we selected the word.
        expect(
          SuperEditorInspector.findDocumentSelection(),
          const DocumentSelection(
            base: DocumentPosition(
              nodeId: '1',
              nodePosition: TextNodePosition(offset: 11),
            ),
            extent: DocumentPosition(
              nodeId: '1',
              nodePosition: TextNodePosition(offset: 19),
            ),
          ),
        );

        await tester.typeKeyboardText("a");

        // Ensure the selected content was deleted.
        expect(SuperEditorInspector.findTextInParagraph("1").text, "Text with [a] selection");
        expect(
          SuperEditorInspector.findDocumentSelection(),
          const DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: '1',
              nodePosition: TextNodePosition(offset: 12),
            ),
          ),
        );
      });

      testWidgetsOnMac('collapses selection if escape is pressed', (tester) async {
        await tester //
            .createDocument()
            .withCustomContent(
              MutableDocument(
                nodes: [
                  ParagraphNode(
                    id: '1',
                    text: AttributedText('Text with [SELECTME] selection'),
                  ),
                ],
              ),
            )
            .pump();

        // Select "SELECTME" by double-tapping.
        await tester.doubleTapInParagraph("1", 14);

        // Ensure that we selected the word.
        expect(
          SuperEditorInspector.findDocumentSelection(),
          const DocumentSelection(
            base: DocumentPosition(
              nodeId: '1',
              nodePosition: TextNodePosition(offset: 11),
            ),
            extent: DocumentPosition(
              nodeId: '1',
              nodePosition: TextNodePosition(offset: 19),
            ),
          ),
        );

        await tester.pressEscape();

        // Ensure the selected content was deleted.
        expect(SuperEditorInspector.findTextInParagraph("1").text, "Text with [SELECTME] selection");
        expect(
          SuperEditorInspector.findDocumentSelection(),
          const DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: '1',
              nodePosition: TextNodePosition(offset: 19),
            ),
          ),
        );
      });
    });

    testWidgetsOnMac('does nothing when escape is pressed if the selection is collapsed', (tester) async {
      await tester //
          .createDocument()
          .withCustomContent(
            MutableDocument(
              nodes: [
                ParagraphNode(
                  id: '1',
                  text: AttributedText('This is some text'),
                ),
              ],
            ),
          )
          .pump();

      // Select "SELECTME" by double-tapping.
      await tester.placeCaretInParagraph("1", 8);

      await tester.pressEscape();

      // Ensure that nothing changed.
      expect(SuperEditorInspector.findTextInParagraph("1").text, "This is some text");
      expect(
        SuperEditorInspector.findDocumentSelection(),
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: '1',
            nodePosition: TextNodePosition(offset: 8),
          ),
        ),
      );
    });

    group("page scrolling", () {
      testWidgetsOnAllPlatforms(
        'PAGE DOWN scrolls down by the viewport height',
        (tester) async {
          await _scrollingVariant.currentValue!.pumpEditor(
            tester,
            _scrollingVariant.currentValue!.textInputSource,
          );

          await tester.placeCaretInParagraph('1', 0);

          final scrollState = tester.state<ScrollableState>(find.byType(Scrollable));

          await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);

          // Let the scrolling system auto-scroll, as desired.
          await tester.pumpAndSettle();

          // Ensure we scrolled down by the viewport height.
          expect(
            scrollState.position.pixels,
            equals(scrollState.position.viewportDimension),
          );
        },
        variant: _scrollingVariant,
      );

      testWidgetsOnAllPlatforms(
        'PAGE DOWN does not scroll past bottom of the viewport',
        (tester) async {
          await _scrollingVariant.currentValue!.pumpEditor(
            tester,
            _scrollingVariant.currentValue!.textInputSource,
          );

          await tester.placeCaretInParagraph('1', 0);

          final scrollState = tester.state<ScrollableState>(find.byType(Scrollable));

          // Scroll very close to the bottom but not all the way to avoid explicit
          // checks comparing scroll offset directly against `maxScrollExtent`
          // and test scrolling behaviour in more realistic manner.
          scrollState.position.jumpTo(scrollState.position.maxScrollExtent - 10);

          await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);

          // Let the scrolling system auto-scroll, as desired.
          await tester.pumpAndSettle();

          // Ensure we didn't scroll past the bottom of the viewport.
          expect(scrollState.position.pixels, equals(scrollState.position.maxScrollExtent));
        },
        variant: _scrollingVariant,
      );

      testWidgetsOnAllPlatforms(
        'PAGE UP scrolls up by the viewport height',
        (tester) async {
          await _scrollingVariant.currentValue!.pumpEditor(
            tester,
            _scrollingVariant.currentValue!.textInputSource,
          );

          await tester.placeCaretInParagraph('1', 0);

          final scrollState = tester.state<ScrollableState>(find.byType(Scrollable));

          // Scroll to the bottom of the viewport.
          scrollState.position.jumpTo(scrollState.position.maxScrollExtent);

          await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);

          // Let the scrolling system auto-scroll, as desired.
          await tester.pumpAndSettle();

          // Ensure we scrolled up by the viewport height.
          expect(
            scrollState.position.pixels,
            equals(scrollState.position.maxScrollExtent - scrollState.position.viewportDimension),
          );
        },
        variant: _scrollingVariant,
      );

      testWidgetsOnAllPlatforms(
        'PAGE UP does not scroll past top of the viewport',
        (tester) async {
          await _scrollingVariant.currentValue!.pumpEditor(
            tester,
            _scrollingVariant.currentValue!.textInputSource,
          );

          await tester.placeCaretInParagraph('1', 0);

          final scrollState = tester.state<ScrollableState>(find.byType(Scrollable));

          // Scroll very close to the top but not all the way to avoid explicit
          // checks comparing scroll offset directly against `minScrollExtent`
          // and test scrolling behaviour in more realistic manner.
          scrollState.position.jumpTo(scrollState.position.minScrollExtent + 10);

          await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);

          // Let the scrolling system auto-scroll, as desired.
          await tester.pumpAndSettle();

          // Ensure we didn't scroll past the top of the viewport.
          expect(scrollState.position.pixels, equals(scrollState.position.minScrollExtent));
        },
        variant: _scrollingVariant,
      );

      testWidgetsOnAllPlatforms(
        'CMD + HOME on mac/ios and CTRL + HOME on other platforms scrolls to top of viewport',
        (tester) async {
          await _scrollingVariant.currentValue!.pumpEditor(
            tester,
            _scrollingVariant.currentValue!.textInputSource,
          );

          await tester.placeCaretInParagraph('1', 0);

          final scrollState = tester.state<ScrollableState>(find.byType(Scrollable));

          // Scroll to the bottom of the viewport.
          scrollState.position.jumpTo(scrollState.position.maxScrollExtent);

          if (defaultTargetPlatform == TargetPlatform.macOS || defaultTargetPlatform == TargetPlatform.iOS) {
            await _pressCmdHome(tester);
          } else {
            await _pressCtrlHome(tester);
          }

          // Ensure we scrolled to the top of the viewport.
          expect(
            scrollState.position.pixels,
            equals(scrollState.position.minScrollExtent),
          );
        },
        variant: _scrollingVariant,
      );

      testWidgetsOnAllPlatforms(
        "CMD + HOME on mac/ios and CTRL + HOME on other platforms does not scroll past top of the viewport",
        (tester) async {
          await _scrollingVariant.currentValue!.pumpEditor(
            tester,
            _scrollingVariant.currentValue!.textInputSource,
          );

          await tester.placeCaretInParagraph('1', 0);

          final scrollState = tester.state<ScrollableState>(find.byType(Scrollable));

          // Scroll very close to the top but not all the way to avoid explicit
          // checks comparing scroll offset directly against `minScrollExtent`
          // and test scrolling behaviour in more realistic manner.
          scrollState.position.jumpTo(scrollState.position.minScrollExtent + 10);

          if (defaultTargetPlatform == TargetPlatform.macOS || defaultTargetPlatform == TargetPlatform.iOS) {
            await _pressCmdHome(tester);
          } else {
            await _pressCtrlHome(tester);
          }

          // Ensure we didn't scroll past the top of the viewport.
          expect(scrollState.position.pixels, equals(scrollState.position.minScrollExtent));
        },
        variant: _scrollingVariant,
      );

      testWidgetsOnAllPlatforms(
        "CMD + END on mac/ios and CTRL + END on other platforms scrolls to bottom of viewport",
        (tester) async {
          await _scrollingVariant.currentValue!.pumpEditor(
            tester,
            _scrollingVariant.currentValue!.textInputSource,
          );

          await tester.placeCaretInParagraph('1', 0);

          final scrollState = tester.state<ScrollableState>(find.byType(Scrollable));

          if (defaultTargetPlatform == TargetPlatform.macOS || defaultTargetPlatform == TargetPlatform.iOS) {
            await _pressCmdEnd(tester);
          } else {
            await _pressCtrlEnd(tester);
          }

          // Ensure we scrolled to the bottom of the viewport.
          expect(scrollState.position.pixels, equals(scrollState.position.maxScrollExtent));
        },
        variant: _scrollingVariant,
      );

      testWidgetsOnAllPlatforms(
        "CMD + END on mac/ios and CTRL + END on other platforms does not scroll past bottom of the viewport",
        (tester) async {
          await _scrollingVariant.currentValue!.pumpEditor(
            tester,
            _scrollingVariant.currentValue!.textInputSource,
          );

          await tester.placeCaretInParagraph('1', 0);

          final scrollState = tester.state<ScrollableState>(find.byType(Scrollable));

          // Scroll very close to the bottom but not all the way to avoid explicit
          // checks comparing scroll offset directly against `maxScrollExtent`
          // and test scrolling behaviour in more realistic manner.
          scrollState.position.jumpTo(scrollState.position.maxScrollExtent - 10);

          if (defaultTargetPlatform == TargetPlatform.macOS || defaultTargetPlatform == TargetPlatform.iOS) {
            await _pressCmdEnd(tester);
          } else {
            await _pressCtrlEnd(tester);
          }

          // Ensure we didn't scroll past the bottom of the viewport.
          expect(scrollState.position.pixels, equals(scrollState.position.maxScrollExtent));
        },
        variant: _scrollingVariant,
      );
    });
  });
}

/// Pumps a [SuperEditor] with a single-paragraph document, with focus, and returns
/// the associated [SuperEditorContext] for further inspection and control.
///
/// This particular setup is intended for caret movement testing within a single
/// paragraph node.
Future<TestDocumentContext> _pumpCaretMovementTestSetup(
  WidgetTester tester, {
  required int textOffsetInFirstNode,
}) async {
  final focusNode = FocusNode()..requestFocus();
  final context = await tester //
      .createDocument()
      .withSingleParagraph()
      .withFocusNode(focusNode)
      .pump();

  await tester.placeCaretInParagraph("1", textOffsetInFirstNode);

  return context;
}

Future<TestDocumentContext> _pumpAutoWrappingTestSetup(WidgetTester tester) async {
  return await tester //
      .createDocument()
      .withSingleParagraph()
      .forDesktop()
      .withEditorSize(const Size(400, 400))
      .pump();
}

Future<TestDocumentContext> _pumpExplicitLineBreakTestSetup(
  WidgetTester tester, {
  Size? size,
}) async {
  return await tester
      .createDocument()
      .withCustomContent(MutableDocument(
        nodes: [
          ParagraphNode(
            id: '1',
            text: AttributedText(
              'Lorem ipsum dolor sit amet\nconsectetur adipiscing elit',
            ),
          ),
        ],
      ))
      .forDesktop()
      .withEditorSize(size)
      .pump();
}

/// Variant for an editor experience with an internal scrollable and
/// an ancestor scrollable.
final _scrollingVariant = ValueVariant<_PageScrollSetup>({
  const _PageScrollSetup(
    description: "inner viewport",
    pumpEditor: _pumpPageScrollTestSetup,
    textInputSource: TextInputSource.ime,
  ),
  const _PageScrollSetup(
    description: "inner viewport",
    pumpEditor: _pumpPageScrollTestSetup,
    textInputSource: TextInputSource.keyboard,
  ),
  const _PageScrollSetup(
    description: "ancestor viewport",
    pumpEditor: _pumpPageScrollSliverTestSetup,
    textInputSource: TextInputSource.ime,
  ),
  const _PageScrollSetup(
    description: "ancestor viewport",
    pumpEditor: _pumpPageScrollSliverTestSetup,
    textInputSource: TextInputSource.keyboard,
  ),
});

/// Pumps a [SuperEditor] experience with the default [Scrollable].
Future<TestDocumentContext> _pumpPageScrollTestSetup(
  WidgetTester tester,
  TextInputSource textInputSource,
) async {
  return await tester //
      .createDocument()
      .withLongDoc()
      .withInputSource(textInputSource)
      .pump();
}

/// Pumps a [SuperEditor] within a ancestor [Scrollable], including additional
/// content above the [SuperEditor] and additional content on top of [Scrollable].
///
/// By including content above the [SuperEditor], it doesn't have the same origin as
/// the ancestor [Scrollable].
///
/// By including content on top of [Scrollable], it doesn't have the origin
/// at [Offset.zero].
///
/// This setup is intended for testing page scrolling actions behaviour in presense
/// of an ancestor [Scrollable].
Future<TestDocumentContext> _pumpPageScrollSliverTestSetup(
  WidgetTester tester,
  TextInputSource textInputSource,
) async {
  return tester //
      .createDocument()
      .withLongDoc()
      .withInputSource(textInputSource)
      .withCustomWidgetTreeBuilder((superEditor) {
    return MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.only(top: 300),
          child: CustomScrollView(
            slivers: [
              const SliverAppBar(
                title: Text(
                  'Rich Text Editor Sliver Example',
                ),
                expandedHeight: 200.0,
              ),
              SliverToBoxAdapter(
                child: superEditor,
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (BuildContext context, int index) {
                    return ListTile(title: Text('$index'));
                  },
                  childCount: 100,
                ),
              ),
            ],
          ),
        ),
      ),
      debugShowCheckedModeBanner: false,
    );
  }).pump();
}

Future<void> _pressCmdHome(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.meta, platform: 'macos');
  await tester.sendKeyDownEvent(LogicalKeyboardKey.home, platform: 'macos');
  await tester.sendKeyUpEvent(LogicalKeyboardKey.meta, platform: 'macos');
  await tester.sendKeyUpEvent(LogicalKeyboardKey.home, platform: 'macos');
  await tester.pumpAndSettle();
}

Future<void> _pressCmdEnd(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.meta, platform: 'macos');
  await tester.sendKeyDownEvent(LogicalKeyboardKey.end, platform: 'macos');
  await tester.sendKeyUpEvent(LogicalKeyboardKey.meta, platform: 'macos');
  await tester.sendKeyUpEvent(LogicalKeyboardKey.end, platform: 'macos');
  await tester.pumpAndSettle();
}

Future<void> _pressCtrlHome(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.control, platform: 'macos');
  await tester.sendKeyDownEvent(LogicalKeyboardKey.home, platform: 'macos');
  await tester.sendKeyUpEvent(LogicalKeyboardKey.control, platform: 'macos');
  await tester.sendKeyUpEvent(LogicalKeyboardKey.home, platform: 'macos');
  await tester.pumpAndSettle();
}

Future<void> _pressCtrlEnd(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.control, platform: 'macos');
  await tester.sendKeyDownEvent(LogicalKeyboardKey.end, platform: 'macos');
  await tester.sendKeyUpEvent(LogicalKeyboardKey.control, platform: 'macos');
  await tester.sendKeyUpEvent(LogicalKeyboardKey.end, platform: 'macos');
  await tester.pumpAndSettle();
}

/// Holds the setup for a page scroll test.
class _PageScrollSetup {
  const _PageScrollSetup({
    required this.description,
    required this.pumpEditor,
    required this.textInputSource,
  });
  final String description;
  final _PumpEditorWidget pumpEditor;
  final TextInputSource textInputSource;

  @override
  String toString() {
    return "PageScrollSetup: $description, ${textInputSource.toString()}";
  }
}

typedef _PumpEditorWidget = Future<TestDocumentContext> Function(
  WidgetTester tester,
  TextInputSource textInputSource,
);
