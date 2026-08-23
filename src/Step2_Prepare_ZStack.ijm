// ============================================================================
// STEP 2 — PREPARE Z-STACK
// Version 2 — forced visual inspection + revisable Z-range
//
// INPUT:
//   Student selects the SAME original .ims file used in Step 1.
//
// CORE RULES:
//   • The FULL Z-stack is the DEFAULT analysis range.
//   • The student MUST visually inspect the image before any range is finalized.
//   • During inspection, they visually choose a candidate FIRST and LAST plane.
//   • They can reject that candidate and inspect again as many times as needed.
//   • ONLY AFTER the required visual inspection may they override with:
//         1) the ENTIRE Z-stack, or
//         2) a known numeric Z-range.
//   • Nothing is saved until a final range is explicitly approved.
//
// NO orientation.
// NO filtering.
// NO projection.
// ============================================================================

requires("1.53");

// ----------------------------------------------------------------------------
// 0. WELCOME
// ----------------------------------------------------------------------------
Dialog.create("Step 2 — Choose analysis Z-range");
Dialog.addMessage(
    "This step determines which Z-planes will be used for analysis.\n\n" +
    "IMPORTANT:\n" +
    "• The ENTIRE Z-stack is the default.\n" +
    "• You must inspect the image before choosing a final range.\n" +
    "• You can go back and change your selection as many times as needed.\n" +
    "• After inspection, you may instead choose the entire stack or enter\n" +
    "  a known Z-range manually.\n\n" +
    "Select the SAME original .ims file used in Step 1."
);
Dialog.show();

// ----------------------------------------------------------------------------
// 1. SELECT ORIGINAL IMS
// ----------------------------------------------------------------------------
inputPath = File.openDialog("Step 2 — Select the SAME original .ims file");

if (inputPath == "")
    exit("No file was selected.\n\nNothing was changed.");

inputFileName = File.getName(inputPath);
inputFolder = File.getParent(inputPath) + File.separator;
lowerName = toLowerCase(inputFileName);

if (!endsWith(lowerName, ".ims"))
    exit(
        "Wrong file type selected.\n\n" +
        "Step 2 expects the SAME original Imaris (.ims) file used in Step 1.\n\n" +
        "Selected file:\n" + inputFileName
    );

dotPosition = lastIndexOf(inputFileName, ".");
if (dotPosition > 0)
    sampleName = substring(inputFileName, 0, dotPosition);
else
    sampleName = inputFileName;

safeSampleName = makeSafeName(sampleName);

// ----------------------------------------------------------------------------
// 2. FIND STEP 1
// ----------------------------------------------------------------------------
analysisFolder =
    inputFolder +
    safeSampleName +
    "_FijiAnalysis" +
    File.separator;

step1Folder =
    analysisFolder +
    "00_import_and_channels" +
    File.separator;

step1SummaryPath =
    step1Folder +
    safeSampleName +
    "_import_summary.txt";

if (!File.exists(step1SummaryPath))
    exit(
        "STEP 1 WAS NOT FOUND FOR THIS IMAGE.\n\n" +
        "Step 2 looked for:\n" +
        step1SummaryPath + "\n\n" +
        "Please run Step 1 — Identify Image Channels first using this same .ims file.\n\n" +
        "Nothing was changed."
    );

// ----------------------------------------------------------------------------
// 3. READ STEP 1
// ----------------------------------------------------------------------------
step1Text = File.openAsString(step1SummaryPath);
step1Lines = split(step1Text, "\n");

savedChannelCount = -1;
savedMarkers = newArray(5);
savedMarkerCount = 0;
markerMapText = "";

for (i = 0; i < step1Lines.length; i++) {

    line = replace(step1Lines[i], "\r", "");

    if (startsWith(line, "Channels:") && savedChannelCount < 0) {
        value = substring(line, lengthOf("Channels:"));
        savedChannelCount = parseInt(trimString(value));
    }

    if (startsWith(line, "Channel ") && indexOf(line, " -> ") >= 0) {
        arrow = indexOf(line, " -> ");
        left = substring(line, 0, arrow);
        marker = trimString(substring(line, arrow + 4));

        channelNumberText = substring(left, lengthOf("Channel "));
        channelNumber = parseInt(channelNumberText);

        if (channelNumber >= 1 && channelNumber <= 5) {
            savedMarkers[channelNumber - 1] = marker;
            if (channelNumber > savedMarkerCount)
                savedMarkerCount = channelNumber;
        }
    }
}

if (savedChannelCount < 1)
    exit(
        "Step 1 was found, but the saved channel count could not be read.\n\n" +
        "Please ask the instructor to inspect:\n" + step1SummaryPath
    );

if (savedMarkerCount != savedChannelCount)
    exit(
        "Step 1 channel information is incomplete.\n\n" +
        "Please rerun Step 1 for this image."
    );

for (c = 0; c < savedChannelCount; c++)
    markerMapText = markerMapText +
        "Channel " + (c + 1) + "  →  " + savedMarkers[c] + "\n";

// ----------------------------------------------------------------------------
// 4. SHOW STEP 1 INFORMATION
// ----------------------------------------------------------------------------
Dialog.create("Step 2 — Image identified");
Dialog.addMessage(
    "Step 1 was found automatically.\n\n" +
    "IMAGE\n" +
    inputFileName + "\n\n" +
    "CHANNEL MAP\n" +
    markerMapText + "\n" +
    "The original .ims will now open for REQUIRED visual inspection."
);
Dialog.show();

// ----------------------------------------------------------------------------
// 5. OPEN IMS
// ----------------------------------------------------------------------------
beforeImages = nImages;

run(
    "Bio-Formats",
    "open=[" + inputPath + "] " +
    "color_mode=Default " +
    "rois_import=[ROI manager] " +
    "view=Hyperstack " +
    "stack_order=XYCZT " +
    "series_1"
);

if (nImages <= beforeImages)
    exit(
        "Fiji/Bio-Formats did not open the image.\n\n" +
        "Please confirm that it opens normally with File > Import > Bio-Formats."
    );

originalTitle = getTitle();
getDimensions(sizeX, sizeY, sizeC, sizeZ, sizeT);

// ----------------------------------------------------------------------------
// 6. VALIDATE AGAINST STEP 1
// ----------------------------------------------------------------------------
if (sizeC != savedChannelCount) {
    close();
    exit(
        "CHANNEL COUNT DOES NOT MATCH STEP 1.\n\n" +
        "Step 1: " + savedChannelCount + " channel(s)\n" +
        "Current image: " + sizeC + " channel(s)\n\n" +
        "The wrong .ims file may have been selected.\n\n" +
        "Nothing was saved."
    );
}

if (sizeC < 1 || sizeC > 5) {
    close();
    exit(
        "This workflow supports 1–5 channels.\n\n" +
        "Nothing was saved."
    );
}

if (sizeT > 1) {
    close();
    exit(
        "TIME SERIES DETECTED\n\n" +
        "This image contains " + sizeT + " timepoints.\n" +
        "Step 2 currently expects one timepoint.\n\n" +
        "Nothing was saved."
    );
}

// ----------------------------------------------------------------------------
// 7. PREPARE INTERACTIVE IMAGE
// ----------------------------------------------------------------------------
selectWindow(originalTitle);

if (sizeC > 1)
    run("Make Composite");

run("Brightness/Contrast...");

if (sizeC > 1)
    run("Channels Tool...");

// Default range is the entire stack.
finalFirst = 1;
finalLast = sizeZ;
selectionMethod = "Entire Z-stack (default)";

// ----------------------------------------------------------------------------
// 8. REQUIRED VISUAL INSPECTION
// ----------------------------------------------------------------------------
if (sizeZ == 1) {

    waitForUser(
        "Step 2 — Required image inspection",
        "This image contains a single Z-plane.\n\n" +
        markerMapText + "\n" +
        "Inspect the image now. You may switch channels, zoom, pan,\n" +
        "or adjust Brightness/Contrast for viewing.\n\n" +
        "Click OK only after you have inspected the image."
    );

    finalFirst = 1;
    finalLast = 1;
    selectionMethod = "Entire Z-stack (single plane)";

} else {

    // Start at Z=1 so the student encounters the full range deliberately.
    Stack.setPosition(1, 1, 1);

    waitForUser(
        "Step 2 — Inspect the full Z-stack",
        "REQUIRED VISUAL INSPECTION\n\n" +
        "The default analysis range is the ENTIRE stack: Z 1–" + sizeZ + ".\n\n" +
        markerMapText + "\n" +
        "Before choosing anything, inspect the image:\n\n" +
        "• Scroll through the FULL Z-stack from beginning to end.\n" +
        "• Switch channels as needed.\n" +
        "• Zoom/pan as needed.\n" +
        "• Brightness/Contrast adjustments are for viewing only.\n\n" +
        "After you have looked through the stack, click OK."
    );

    // ------------------------------------------------------------------------
    // 9. RANGE-SELECTION LOOP
    // Student can repeatedly inspect until satisfied.
    // ------------------------------------------------------------------------
    rangeFinalized = 0;

    while (rangeFinalized == 0) {

        // Ask whether they want to visually choose a candidate range,
        // or use one of the post-inspection overrides.
        Dialog.create("Step 2 — How should the Z-range be chosen?");
        Dialog.addMessage(
            "You have completed the required visual inspection.\n\n" +
            "DEFAULT RANGE\n" +
            "Entire stack: Z 1–" + sizeZ + "\n\n" +
            "Choose how you want to define the analysis range."
        );

        methods = newArray(
            "Choose a range visually",
            "Use the entire Z-stack",
            "Enter a known Z-range"
        );

        Dialog.addChoice("Z-range method:", methods, "Choose a range visually");
        Dialog.show();

        methodChoice = Dialog.getChoice();

        // --------------------------------------------------------------------
        // OPTION A — VISUAL RANGE
        // --------------------------------------------------------------------
        if (methodChoice == "Choose a range visually") {

            // Begin at first plane for a fresh selection.
            Stack.getPosition(activeC, activeZ, activeT);
            Stack.setPosition(activeC, 1, activeT);

            waitForUser(
                "Step 2 — Choose FIRST Z-plane",
                "Choose the FIRST Z-plane you want to include.\n\n" +
                "Scroll to the desired first plane in the image.\n" +
                "You may switch channels while deciding.\n\n" +
                "When the image is on your desired FIRST plane, click OK."
            );

            Stack.getPosition(tmpC1, candidateFirst, tmpT1);

            Stack.setPosition(tmpC1, candidateFirst, tmpT1);

            waitForUser(
                "Step 2 — Choose LAST Z-plane",
                "First candidate plane recorded: Z " + candidateFirst + "\n\n" +
                "Now scroll to the LAST Z-plane you want to include.\n\n" +
                "When the image is on your desired LAST plane, click OK."
            );

            Stack.getPosition(tmpC2, candidateLast, tmpT2);

            if (candidateLast < candidateFirst) {

                Dialog.create("Invalid Z-range");
                Dialog.addMessage(
                    "The candidate range is not valid.\n\n" +
                    "First plane: Z " + candidateFirst + "\n" +
                    "Last plane: Z " + candidateLast + "\n\n" +
                    "The last plane must be the same as or after the first.\n\n" +
                    "You will return to the range-selection screen."
                );
                Dialog.show();

            } else {

                candidateCount = candidateLast - candidateFirst + 1;

                Dialog.create("Step 2 — Review visual selection");
                Dialog.addMessage(
                    "VISUAL RANGE SELECTED\n\n" +
                    "First Z-plane: " + candidateFirst + "\n" +
                    "Last Z-plane: " + candidateLast + "\n" +
                    "Planes retained: " + candidateCount + "\n\n" +
                    "Do you want to use this range?"
                );

                reviewChoices = newArray(
                    "Yes — use this range",
                    "No — inspect and choose again",
                    "Use the entire Z-stack instead",
                    "Enter a known Z-range instead"
                );

                Dialog.addChoice(
                    "Next action:",
                    reviewChoices,
                    "Yes — use this range"
                );
                Dialog.show();

                reviewChoice = Dialog.getChoice();

                if (reviewChoice == "Yes — use this range") {
                    finalFirst = candidateFirst;
                    finalLast = candidateLast;
                    selectionMethod = "Visually selected range";
                    rangeFinalized = 1;
                }

                if (reviewChoice == "No — inspect and choose again") {
                    // Nothing finalized. Loop returns to method screen.
                    // Student keeps full image interaction.
                }

                if (reviewChoice == "Use the entire Z-stack instead") {
                    finalFirst = 1;
                    finalLast = sizeZ;
                    selectionMethod = "Entire Z-stack override after inspection";
                    rangeFinalized = 1;
                }

                if (reviewChoice == "Enter a known Z-range instead") {
                    // Handle manual override immediately.
                    manualDone = 0;

                    while (manualDone == 0) {

                        Dialog.create("Step 2 — Enter known Z-range");
                        Dialog.addMessage(
                            "Enter a Z-range only if you already know the planes\n" +
                            "that should be analyzed.\n\n" +
                            "Valid range: 1–" + sizeZ
                        );
                        Dialog.addNumber("First Z-plane:", 1, 0);
                        Dialog.addNumber("Last Z-plane:", sizeZ, 0);
                        Dialog.show();

                        mFirst = round(Dialog.getNumber());
                        mLast = round(Dialog.getNumber());

                        if (mFirst < 1 || mLast > sizeZ || mLast < mFirst) {

                            Dialog.create("Invalid manual range");
                            Dialog.addMessage(
                                "That range is invalid.\n\n" +
                                "Valid Z-planes are 1–" + sizeZ + ".\n" +
                                "First must be less than or equal to last."
                            );
                            Dialog.show();

                        } else {

                            finalFirst = mFirst;
                            finalLast = mLast;
                            selectionMethod = "Manual numeric override after inspection";
                            manualDone = 1;
                            rangeFinalized = 1;
                        }
                    }
                }
            }
        }

        // --------------------------------------------------------------------
        // OPTION B — ENTIRE STACK
        // --------------------------------------------------------------------
        if (methodChoice == "Use the entire Z-stack") {

            Dialog.create("Step 2 — Confirm entire Z-stack");
            Dialog.addMessage(
                "You are choosing the ENTIRE Z-stack.\n\n" +
                "Final range: Z 1–" + sizeZ + "\n\n" +
                "This is the default analysis range."
            );
            Dialog.addCheckbox("Yes — use the entire Z-stack.", false);
            Dialog.show();

            useAll = Dialog.getCheckbox();

            if (useAll) {
                finalFirst = 1;
                finalLast = sizeZ;
                selectionMethod = "Entire Z-stack override after inspection";
                rangeFinalized = 1;
            }
            // If unchecked, loop returns to selection screen.
        }

        // --------------------------------------------------------------------
        // OPTION C — KNOWN NUMERIC RANGE
        // --------------------------------------------------------------------
        if (methodChoice == "Enter a known Z-range") {

            manualDone = 0;

            while (manualDone == 0) {

                Dialog.create("Step 2 — Enter known Z-range");
                Dialog.addMessage(
                    "Enter a Z-range only if you already know the planes\n" +
                    "that should be analyzed.\n\n" +
                    "You have already completed the required visual inspection.\n\n" +
                    "Valid range: 1–" + sizeZ
                );
                Dialog.addNumber("First Z-plane:", 1, 0);
                Dialog.addNumber("Last Z-plane:", sizeZ, 0);
                Dialog.show();

                mFirst = round(Dialog.getNumber());
                mLast = round(Dialog.getNumber());

                if (mFirst < 1 || mLast > sizeZ || mLast < mFirst) {

                    Dialog.create("Invalid manual range");
                    Dialog.addMessage(
                        "That range is invalid.\n\n" +
                        "Valid Z-planes are 1–" + sizeZ + ".\n" +
                        "First must be less than or equal to last."
                    );
                    Dialog.show();

                } else {

                    Dialog.create("Review manual Z-range");
                    Dialog.addMessage(
                        "MANUAL RANGE ENTERED\n\n" +
                        "First Z-plane: " + mFirst + "\n" +
                        "Last Z-plane: " + mLast + "\n" +
                        "Planes retained: " + (mLast - mFirst + 1)
                    );

                    manualChoices = newArray(
                        "Yes — use this range",
                        "No — enter a different range",
                        "Return to visual selection"
                    );

                    Dialog.addChoice(
                        "Next action:",
                        manualChoices,
                        "Yes — use this range"
                    );
                    Dialog.show();

                    manualReview = Dialog.getChoice();

                    if (manualReview == "Yes — use this range") {
                        finalFirst = mFirst;
                        finalLast = mLast;
                        selectionMethod = "Manual numeric override after inspection";
                        manualDone = 1;
                        rangeFinalized = 1;
                    }

                    if (manualReview == "No — enter a different range") {
                        // Repeat manual entry loop.
                    }

                    if (manualReview == "Return to visual selection") {
                        manualDone = 1;
                        // rangeFinalized remains 0, returning to outer loop.
                    }
                }
            }
        }
    }
}

// ----------------------------------------------------------------------------
// 10. FINAL CONFIRMATION BEFORE ANYTHING IS SAVED
// ----------------------------------------------------------------------------
retainedSlices = finalLast - finalFirst + 1;

finalConfirmed = 0;

while (finalConfirmed == 0) {

    Dialog.create("Step 2 — FINAL Z-range");
    Dialog.addMessage(
        "Nothing has been saved yet.\n\n" +
        "FINAL ANALYSIS RANGE\n" +
        "Method: " + selectionMethod + "\n" +
        "Z-planes: " + finalFirst + "–" + finalLast + "\n" +
        "Planes retained: " + retainedSlices + " of " + sizeZ + "\n\n" +
        "CHANNELS RETAINED\n" +
        markerMapText
    );

    finalChoices = newArray(
        "Confirm and save",
        "No — go back and choose again"
    );

    Dialog.addChoice(
        "Final decision:",
        finalChoices,
        "Confirm and save"
    );
    Dialog.show();

    finalDecision = Dialog.getChoice();

    if (finalDecision == "Confirm and save") {
        finalConfirmed = 1;
    } else {

        // For multi-Z images, reopen the selection process.
        if (sizeZ > 1) {
            rangeFinalized = 0;

            while (rangeFinalized == 0) {

                Dialog.create("Step 2 — Revise Z-range");
                Dialog.addMessage(
                    "The previous range was NOT saved.\n\n" +
                    "Choose how you want to revise it."
                );

                reviseMethods = newArray(
                    "Choose a range visually",
                    "Use the entire Z-stack",
                    "Enter a known Z-range"
                );

                Dialog.addChoice(
                    "Z-range method:",
                    reviseMethods,
                    "Choose a range visually"
                );
                Dialog.show();

                reviseChoice = Dialog.getChoice();

                if (reviseChoice == "Choose a range visually") {

                    Stack.getPosition(rc, rz, rt);
                    Stack.setPosition(rc, 1, rt);

                    waitForUser(
                        "Step 2 — Revise FIRST Z-plane",
                        "Scroll to the new FIRST Z-plane and click OK."
                    );
                    Stack.getPosition(rc1, rFirst, rt1);

                    waitForUser(
                        "Step 2 — Revise LAST Z-plane",
                        "First plane recorded: Z " + rFirst + "\n\n" +
                        "Scroll to the new LAST Z-plane and click OK."
                    );
                    Stack.getPosition(rc2, rLast, rt2);

                    if (rLast < rFirst) {
                        Dialog.create("Invalid Z-range");
                        Dialog.addMessage(
                            "First: Z " + rFirst + "\n" +
                            "Last: Z " + rLast + "\n\n" +
                            "Please choose again."
                        );
                        Dialog.show();
                    } else {
                        finalFirst = rFirst;
                        finalLast = rLast;
                        selectionMethod = "Visually selected range";
                        rangeFinalized = 1;
                    }
                }

                if (reviseChoice == "Use the entire Z-stack") {
                    finalFirst = 1;
                    finalLast = sizeZ;
                    selectionMethod = "Entire Z-stack override after inspection";
                    rangeFinalized = 1;
                }

                if (reviseChoice == "Enter a known Z-range") {

                    Dialog.create("Step 2 — Revise known Z-range");
                    Dialog.addMessage("Valid Z range: 1–" + sizeZ);
                    Dialog.addNumber("First Z-plane:", finalFirst, 0);
                    Dialog.addNumber("Last Z-plane:", finalLast, 0);
                    Dialog.show();

                    rrFirst = round(Dialog.getNumber());
                    rrLast = round(Dialog.getNumber());

                    if (rrFirst >= 1 && rrLast <= sizeZ && rrLast >= rrFirst) {
                        finalFirst = rrFirst;
                        finalLast = rrLast;
                        selectionMethod = "Manual numeric override after inspection";
                        rangeFinalized = 1;
                    } else {
                        Dialog.create("Invalid Z-range");
                        Dialog.addMessage(
                            "That range is invalid.\n\n" +
                            "Please choose again."
                        );
                        Dialog.show();
                    }
                }
            }

            retainedSlices = finalLast - finalFirst + 1;

        } else {
            finalConfirmed = 1;
        }
    }
}

// ----------------------------------------------------------------------------
// 11. CREATE OUTPUT FOLDER
// ----------------------------------------------------------------------------
step2Folder =
    analysisFolder +
    "01_prepared_zstack" +
    File.separator;

File.makeDirectory(step2Folder);

outputTiff =
    step2Folder +
    safeSampleName +
    "_prepared_zstack.tif";

settingsPath =
    step2Folder +
    safeSampleName +
    "_zstack_settings.txt";

// ----------------------------------------------------------------------------
// 12. DUPLICATE FINAL RANGE
// ----------------------------------------------------------------------------
closeInspectionTools();
selectWindow(originalTitle);

if (sizeC == 1) {
    run(
        "Duplicate...",
        "title=[" + safeSampleName + "_prepared_zstack] " +
        "duplicate slices=" + finalFirst + "-" + finalLast
    );
} else {
    run(
        "Duplicate...",
        "title=[" + safeSampleName + "_prepared_zstack] " +
        "duplicate " +
        "channels=1-" + sizeC + " " +
        "slices=" + finalFirst + "-" + finalLast + " " +
        "frames=1"
    );
}

preparedTitle = getTitle();

getDimensions(outX, outY, outC, outZ, outT);

if (outC != sizeC || outZ != retainedSlices) {
    close();
    selectWindow(originalTitle);
    close();

    exit(
        "Step 2 could not verify the prepared Z-stack.\n\n" +
        "Expected " + sizeC + " channel(s) and " + retainedSlices + " Z-plane(s).\n" +
        "Prepared image contained " + outC + " channel(s) and " + outZ + " Z-plane(s).\n\n" +
        "Nothing was saved."
    );
}

// ----------------------------------------------------------------------------
// 13. SAVE TIFF
// ----------------------------------------------------------------------------
saveAs("Tiff", outputTiff);

// ----------------------------------------------------------------------------
// 14. SAVE SETTINGS
// ----------------------------------------------------------------------------
settings =
    "STEP 2 — Z-STACK PREPARATION\n" +
    "============================\n\n" +

    "SOURCE IMAGE\n" +
    "File name: " + inputFileName + "\n" +
    "Source path: " + inputPath + "\n\n" +

    "STEP 1 SOURCE\n" +
    "Channel map source: " + step1SummaryPath + "\n\n" +

    "CHANNEL MAP\n" +
    markerMapText + "\n" +

    "ORIGINAL IMAGE STRUCTURE\n" +
    "Width: " + sizeX + " pixels\n" +
    "Height: " + sizeY + " pixels\n" +
    "Channels: " + sizeC + "\n" +
    "Z-planes: " + sizeZ + "\n" +
    "Timepoints: " + sizeT + "\n\n" +

    "FINAL Z-RANGE\n" +
    "Selection method: " + selectionMethod + "\n" +
    "First retained Z-plane: " + finalFirst + "\n" +
    "Last retained Z-plane: " + finalLast + "\n" +
    "Total retained Z-planes: " + retainedSlices + "\n" +
    "Original total Z-planes: " + sizeZ + "\n\n" +

    "OUTPUT\n" +
    "Prepared stack: " + outputTiff + "\n" +
    "Output channels: " + outC + "\n" +
    "Output Z-planes: " + outZ + "\n\n" +

    "PROCESSING STATUS\n" +
    "Required visual inspection was completed before range finalization.\n" +
    "All channels were retained.\n" +
    "No orientation change was applied.\n" +
    "No filtering was applied.\n" +
    "No projection was applied.\n" +
    "Brightness/contrast changes during inspection were display-only.\n";

File.saveString(settings, settingsPath);

// ----------------------------------------------------------------------------
// 15. CLEAN UP
// ----------------------------------------------------------------------------
// saveAs() may rename the prepared image window to the saved TIFF filename.
// Therefore, do NOT try to select it using the temporary pre-save title.
// The prepared stack is still the active image immediately after saving.
close();

// Now close the original .ims image.
if (isOpen(originalTitle)) {
    selectWindow(originalTitle);
    close();
}

// ----------------------------------------------------------------------------
// 16. COMPLETE
// ----------------------------------------------------------------------------
Dialog.create("Step 2 complete");
Dialog.addMessage(
    "The prepared Z-stack was saved successfully.\n\n" +
    "FINAL RANGE\n" +
    "Method: " + selectionMethod + "\n" +
    "Z " + finalFirst + "–" + finalLast +
    " (" + retainedSlices + " of " + sizeZ + " planes)\n\n" +
    "CHANNELS\n" +
    markerMapText + "\n" +
    "SAVED IN\n" +
    step2Folder + "\n\n" +
    "Future analysis steps should use:\n" +
    File.getName(outputTiff)
);
Dialog.show();


// ============================================================================
// FUNCTIONS
// ============================================================================

function makeSafeName(s) {
    s = replace(s, " ", "_");
    s = replace(s, "/", "_");
    s = replace(s, "\\", "_");
    s = replace(s, ":", "_");
    s = replace(s, "[", "_");
    s = replace(s, "]", "_");
    s = replace(s, ",", "_");
    return s;
}

function trimString(s) {
    while (
        lengthOf(s) > 0 &&
        (startsWith(s, " ") || startsWith(s, "\t"))
    )
        s = substring(s, 1);

    while (
        lengthOf(s) > 0 &&
        (endsWith(s, " ") || endsWith(s, "\t"))
    )
        s = substring(s, 0, lengthOf(s) - 1);

    return s;
}

function closeInspectionTools() {
    if (isOpen("B&C"))
        close("B&C");

    if (isOpen("Channels"))
        close("Channels");
}
