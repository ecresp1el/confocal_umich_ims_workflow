// ============================================================================
// STEP 3 — FULL-IMAGE MAX PROJECTIONS + FIGURES
// Version 1
//
// INPUT:
//   Select the *_prepared_zstack.tif created by Step 2.
//
// AUTOMATICALLY RECOVERS:
//   Step 1 channel labels from:
//     <Sample>_FijiAnalysis/00_import_and_channels/<Sample>_import_summary.txt
//
// WORKFLOW:
//   1. Open prepared multichannel Z-stack.
//   2. Verify channel map and dimensions.
//   3. Make MAX projection for every channel.
//   4. Student chooses a display color for every marker.
//   5. Student interactively adjusts brightness/contrast for every MAX image.
//      Each display range can be rejected and adjusted again.
//   6. Save raw MAX TIFFs.
//   7. Save display-colored individual TIFF/PNG images.
//   8. Build + save editable multichannel MAX composite.
//   9. Build + save full RGB merge.
//  10. Build + save labeled "individual channels + merge" panel.
//  11. Build + save every PAIRWISE channel combination.
//  12. Build + save labeled pairwise summary panel.
//
// IMPORTANT:
//   • Display-range changes do NOT modify the raw MAX pixel values.
//   • Labels are placed ABOVE the microscopy images, never over them.
//   • Marker-label text is color-matched to the selected display color.
//   • Supports 1–5 channels, in any order.
// ============================================================================

requires("1.53");

// ----------------------------------------------------------------------------
// 0. WELCOME
// ----------------------------------------------------------------------------
Dialog.create("Step 3 — Full-image figures");
Dialog.addMessage(
    "Step 3 creates the full-field MAX projections and figure set.\n\n" +
    "Select the *_prepared_zstack.tif created by Step 2.\n\n" +
    "You will:\n" +
    "• choose a display color for each marker\n" +
    "• adjust each marker's display range interactively\n" +
    "• review/re-adjust before accepting it\n\n" +
    "Step 3 will then automatically create:\n" +
    "• individual marker images\n" +
    "• complete merged image\n" +
    "• labeled marker + merge panel\n" +
    "• all pairwise channel combinations\n" +
    "• labeled pairwise summary panel\n\n" +
    "No ROI is selected in this step."
);
Dialog.show();

// ----------------------------------------------------------------------------
// 1. SELECT STEP 2 TIFF
// ----------------------------------------------------------------------------
inputPath = File.openDialog(
    "Step 3 — Select the *_prepared_zstack.tif created by Step 2"
);

if (inputPath == "")
    exit("No file was selected.\n\nNothing was changed.");

inputFileName = File.getName(inputPath);
inputFolder = File.getParent(inputPath) + File.separator;
lowerName = toLowerCase(inputFileName);

if (!endsWith(lowerName, ".tif") && !endsWith(lowerName, ".tiff"))
    exit(
        "Wrong file type selected.\n\n" +
        "Step 3 expects the TIFF created by Step 2."
    );

suffix = "_prepared_zstack";
dotPosition = lastIndexOf(inputFileName, ".");
if (dotPosition > 0)
    fileBase = substring(inputFileName, 0, dotPosition);
else
    fileBase = inputFileName;

if (!endsWith(fileBase, suffix))
    exit(
        "This does not look like a Step 2 prepared stack.\n\n" +
        "Expected a file ending in:\n" +
        "_prepared_zstack.tif\n\n" +
        "Selected:\n" + inputFileName
    );

safeSampleName = substring(fileBase, 0, lengthOf(fileBase) - lengthOf(suffix));

// Step 2 folder should be:
// <Sample>_FijiAnalysis/01_prepared_zstack/
analysisFolder = File.getParent(inputFolder) + File.separator;

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
        "STEP 1 CHANNEL INFORMATION WAS NOT FOUND.\n\n" +
        "Step 3 looked for:\n" +
        step1SummaryPath + "\n\n" +
        "Please confirm you selected the Step 2 TIFF from the correct\n" +
        "<Sample>_FijiAnalysis folder."
    );

// ----------------------------------------------------------------------------
// 2. READ STEP 1 CHANNEL MAP
// ----------------------------------------------------------------------------
step1Text = File.openAsString(step1SummaryPath);
step1Lines = split(step1Text, "\n");

savedChannelCount = -1;
markers = newArray(5);
savedMarkerCount = 0;

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
            markers[channelNumber - 1] = marker;
            if (channelNumber > savedMarkerCount)
                savedMarkerCount = channelNumber;
        }
    }
}

if (savedChannelCount < 1 || savedMarkerCount != savedChannelCount)
    exit(
        "Step 1 channel information could not be read reliably.\n\n" +
        "Please rerun Step 1 or ask the instructor to inspect the analysis folder."
    );

markerMapText = "";
for (c = 0; c < savedChannelCount; c++)
    markerMapText = markerMapText +
        "Channel " + (c + 1) + "  →  " + markers[c] + "\n";

// ----------------------------------------------------------------------------
// 3. OPEN PREPARED STACK + VERIFY
// ----------------------------------------------------------------------------
open(inputPath);

if (nImages == 0)
    exit("The prepared TIFF could not be opened.");

originalTitle = getTitle();

getDimensions(
    imageWidth,
    imageHeight,
    channelCount,
    sliceCount,
    frameCount
);

if (channelCount != savedChannelCount) {
    close();
    exit(
        "CHANNEL COUNT DOES NOT MATCH STEP 1.\n\n" +
        "Step 1 recorded: " + savedChannelCount + "\n" +
        "Prepared TIFF contains: " + channelCount + "\n\n" +
        "Nothing was saved."
    );
}

if (channelCount < 1 || channelCount > 5) {
    close();
    exit("Step 3 supports 1–5 channels.");
}

if (frameCount > 1) {
    close();
    exit(
        "The prepared TIFF contains multiple timepoints.\n\n" +
        "Step 3 currently expects one timepoint."
    );
}

// ----------------------------------------------------------------------------
// 4. CONFIRM INPUT
// ----------------------------------------------------------------------------
Dialog.create("Step 3 — Prepared stack identified");
Dialog.addMessage(
    "IMAGE\n" +
    inputFileName + "\n\n" +
    "DIMENSIONS\n" +
    imageWidth + " × " + imageHeight + " pixels\n" +
    channelCount + " channel(s)\n" +
    sliceCount + " Z-plane(s)\n\n" +
    "CHANNEL MAP\n" +
    markerMapText + "\n" +
    "Maximum-intensity projections will be calculated across ALL\n" +
    "Z-planes retained in Step 2."
);
Dialog.show();

// ----------------------------------------------------------------------------
// 5. CHOOSE DISPLAY COLOR FOR EACH MARKER
// ----------------------------------------------------------------------------
lutNames = newArray(
    "Red",
    "Green",
    "Blue",
    "Magenta",
    "Cyan",
    "Yellow",
    "Grays"
);

colors = newArray(channelCount);

Dialog.create("Step 3 — Choose marker colors");
Dialog.addMessage(
    "Choose how each marker should be DISPLAYED in figures.\n\n" +
    "These colors affect visualization only; raw pixel values are unchanged.\n" +
    "Channel order does not determine color."
);

for (c = 0; c < channelCount; c++) {
    defaultColor = defaultColorForMarker(markers[c], c);
    Dialog.addChoice(markers[c] + ":", lutNames, defaultColor);
}

Dialog.show();

for (c = 0; c < channelCount; c++)
    colors[c] = Dialog.getChoice();

// Warn about duplicate display colors, but allow them.
duplicateColorText = "";
for (i = 0; i < channelCount; i++) {
    for (j = i + 1; j < channelCount; j++) {
        if (colors[i] == colors[j])
            duplicateColorText = duplicateColorText +
                markers[i] + " and " + markers[j] +
                " are both " + colors[i] + ".\n";
    }
}

if (duplicateColorText != "") {
    Dialog.create("Check duplicate display colors");
    Dialog.addMessage(
        "Some markers use the same display color:\n\n" +
        duplicateColorText + "\n" +
        "This is allowed, but may make merged images harder to interpret."
    );
    Dialog.addCheckbox("Yes — keep these color choices.", false);
    Dialog.show();

    if (!Dialog.getCheckbox()) {
        close();
        exit(
            "Nothing was saved.\n\n" +
            "Run Step 3 again and choose different display colors."
        );
    }
}

// ----------------------------------------------------------------------------
// 6. CREATE OUTPUT FOLDERS
// ----------------------------------------------------------------------------
step3Folder =
    analysisFolder +
    "02_max_projection_and_figures" +
    File.separator;

individualFolder =
    step3Folder +
    "01_individual_channels" +
    File.separator;

rawMaxFolder =
    individualFolder +
    "raw_max_tiffs" +
    File.separator;

displayIndividualFolder =
    individualFolder +
    "display_images" +
    File.separator;

mergeFolder =
    step3Folder +
    "02_complete_merge" +
    File.separator;

panelFolder =
    step3Folder +
    "03_individual_plus_merge_panel" +
    File.separator;

pairFolder =
    step3Folder +
    "04_pairwise_combinations" +
    File.separator;

pairPanelFolder =
    step3Folder +
    "05_pairwise_summary_panel" +
    File.separator;

// Create EVERY directory level explicitly.
// Fiji's File.makeDirectory() should not be relied upon to create
// missing intermediate folders in a nested path.
File.makeDirectory(step3Folder);
File.makeDirectory(individualFolder);
File.makeDirectory(rawMaxFolder);
File.makeDirectory(displayIndividualFolder);
File.makeDirectory(mergeFolder);
File.makeDirectory(panelFolder);
File.makeDirectory(pairFolder);
File.makeDirectory(pairPanelFolder);

// Verify the key output directories exist before starting projections.
if (!File.exists(rawMaxFolder))
    exit(
        "Step 3 could not create the raw MAX output folder:\n\n" +
        rawMaxFolder + "\n\n" +
        "Nothing was processed."
    );

if (!File.exists(displayIndividualFolder))
    exit(
        "Step 3 could not create the display-image output folder:\n\n" +
        displayIndividualFolder + "\n\n" +
        "Nothing was processed."
    );

// ----------------------------------------------------------------------------
// 7. SPLIT CHANNEL STACKS
// ----------------------------------------------------------------------------
selectWindow(originalTitle);
run("Split Channels");

channelStacks = newArray(channelCount);
for (c = 0; c < channelCount; c++) {
    channelStacks[c] = "C" + (c + 1) + "-" + originalTitle;

    if (!isOpen(channelStacks[c]))
        exit(
            "Could not locate Channel " + (c + 1) +
            " after splitting the prepared TIFF."
        );
}

// ----------------------------------------------------------------------------
// 8. MAKE RAW MAX PROJECTIONS
// ----------------------------------------------------------------------------
maxWindows = newArray(channelCount);
maxBaseNames = newArray(channelCount);
displayMins = newArray(channelCount);
displayMaxs = newArray(channelCount);

for (c = 0; c < channelCount; c++) {

    selectWindow(channelStacks[c]);

    if (sliceCount > 1)
        run("Z Project...", "projection=[Max Intensity]");
    else
        run("Duplicate...", "title=SinglePlane_MAX duplicate");

    markerSafe = makeSafeName(markers[c]);

    maxBaseNames[c] =
        safeSampleName +
        "_MAX_" +
        markerSafe;

    rename(maxBaseNames[c]);
    maxWindows[c] = getTitle();

    // Save RAW max before LUT/display changes.
    saveAs(
        "Tiff",
        rawMaxFolder +
        maxBaseNames[c] +
        ".tif"
    );

    // saveAs can rename window; refresh actual title.
    maxWindows[c] = getTitle();
}

// Close split Z-stacks.
for (c = 0; c < channelCount; c++) {
    if (isOpen(channelStacks[c])) {
        selectWindow(channelStacks[c]);
        close();
    }
}

// The prepared Z-stack is no longer needed after the raw MAX projections exist.
if (isOpen(originalTitle)) {
    selectWindow(originalTitle);
    close();
}

// ----------------------------------------------------------------------------
// 9. INTERACTIVE DISPLAY-RANGE APPROVAL, ONE MARKER AT A TIME
// ----------------------------------------------------------------------------
for (c = 0; c < channelCount; c++) {

    selectWindow(maxWindows[c]);

    applyLUT(colors[c]);

    // Start with Fiji's automatic display range.
    resetMinAndMax();

    run("Brightness/Contrast...");

    rangeApproved = 0;

    while (rangeApproved == 0) {

        waitForUser(
            "Step 3 — Adjust " + markers[c],
            "MARKER: " + markers[c] + "\n" +
            "DISPLAY COLOR: " + colors[c] + "\n\n" +
            "Adjust Brightness/Contrast for DISPLAY.\n\n" +
            "• Inspect the full image.\n" +
            "• Zoom/pan if useful.\n" +
            "• These adjustments do NOT alter the raw MAX pixel values.\n\n" +
            "When this marker looks appropriate, click OK."
        );

        getMinAndMax(tmpMin, tmpMax);

        Dialog.create("Step 3 — Review " + markers[c]);
        Dialog.addMessage(
            "Current display range for " + markers[c] + ":\n\n" +
            "Minimum: " + d2s(tmpMin, 3) + "\n" +
            "Maximum: " + d2s(tmpMax, 3) + "\n\n" +
            "Do you want to keep this display?"
        );

        reviewChoices = newArray(
            "Yes — keep this display",
            "No — adjust it again",
            "Reset to automatic and inspect again"
        );

        Dialog.addChoice(
            "Next action:",
            reviewChoices,
            "Yes — keep this display"
        );
        Dialog.show();

        rangeChoice = Dialog.getChoice();

        if (rangeChoice == "Yes — keep this display") {
            displayMins[c] = tmpMin;
            displayMaxs[c] = tmpMax;
            rangeApproved = 1;
        }

        if (rangeChoice == "Reset to automatic and inspect again") {
            selectWindow(maxWindows[c]);
            resetMinAndMax();
        }
    }

    closeBC();
}

// ----------------------------------------------------------------------------
// 10. FINAL DISPLAY SETTINGS REVIEW
// ----------------------------------------------------------------------------
settingsReview = "";
for (c = 0; c < channelCount; c++) {
    settingsReview = settingsReview +
        markers[c] + "  →  " + colors[c] +
        "   [" + d2s(displayMins[c], 3) +
        " to " + d2s(displayMaxs[c], 3) + "]\n";
}

Dialog.create("Step 3 — Review all marker displays");
Dialog.addMessage(
    "The following display settings will be used for ALL full-image figures:\n\n" +
    settingsReview + "\n" +
    "Labels will be placed above images and color-matched to each marker."
);
Dialog.addCheckbox("These display settings are correct.", false);
Dialog.show();

if (!Dialog.getCheckbox()) {
    closeAllStep3Windows(originalTitle, maxWindows, channelCount);
    exit(
        "Display settings were not approved.\n\n" +
        "Nothing beyond the raw MAX TIFFs was finalized."
    );
}

// ----------------------------------------------------------------------------
// 11. SAVE DISPLAY-COLORED INDIVIDUAL IMAGES
// ----------------------------------------------------------------------------
individualRGBWindows = newArray(channelCount);

for (c = 0; c < channelCount; c++) {

    selectWindow(maxWindows[c]);

    run(
        "Duplicate...",
        "title=[" + safeSampleName +
        "_DISPLAY_" + makeSafeName(markers[c]) + "] duplicate"
    );

    applyLUT(colors[c]);
    setMinAndMax(displayMins[c], displayMaxs[c]);
    run("RGB Color");

    individualRGBWindows[c] = getTitle();

    saveAs(
        "Tiff",
        displayIndividualFolder +
        safeSampleName +
        "_MAX_" +
        makeSafeName(markers[c]) +
        "_" +
        colors[c] +
        ".tif"
    );

    saveAs(
        "PNG",
        displayIndividualFolder +
        safeSampleName +
        "_MAX_" +
        makeSafeName(markers[c]) +
        "_" +
        colors[c] +
        ".png"
    );

    individualRGBWindows[c] = getTitle();

    // Intermediate display image is now safely on disk; close it to save RAM.
    close();
    individualRGBWindows[c] = "";
}

// ----------------------------------------------------------------------------
// 12. BUILD EDITABLE MULTICHANNEL MAX COMPOSITE
// ----------------------------------------------------------------------------
// Use RAW MAX windows as merge inputs.
mergeOptions = "";

for (c = 0; c < channelCount; c++)
    mergeOptions = mergeOptions +
        "c" + (c + 1) + "=[" + maxWindows[c] + "] ";

mergeOptions = mergeOptions + "create keep";

run("Merge Channels...", mergeOptions);

editableCompositeTitle =
    safeSampleName +
    "_MAX_merged_composite";

rename(editableCompositeTitle);

// Restore marker LUTs + display ranges.
for (c = 0; c < channelCount; c++) {
    Stack.setChannel(c + 1);
    applyLUT(colors[c]);
    setMinAndMax(displayMins[c], displayMaxs[c]);
}

Stack.setDisplayMode("composite");
Stack.setActiveChannels(allChannelsMask(channelCount));

saveAs(
    "Tiff",
    mergeFolder +
    editableCompositeTitle +
    ".tif"
);

editableCompositeTitle = getTitle();

// ----------------------------------------------------------------------------
// 13. CREATE FULL RGB MERGE
// ----------------------------------------------------------------------------
selectWindow(editableCompositeTitle);

run(
    "Duplicate...",
    "title=[" + safeSampleName + "_MAX_Merge_RGB] duplicate"
);

Stack.setDisplayMode("composite");
Stack.setActiveChannels(allChannelsMask(channelCount));
run("RGB Color");

fullMergeRGBWindow = getTitle();

saveAs(
    "Tiff",
    mergeFolder +
    safeSampleName +
    "_MAX_Merge_RGB.tif"
);

saveAs(
    "PNG",
    mergeFolder +
    safeSampleName +
    "_MAX_Merge_RGB.png"
);

fullMergeRGBWindow = getTitle();

// The full merge has been saved; close the display copy to conserve RAM.
close();
fullMergeRGBWindow = "";

// ----------------------------------------------------------------------------
// 14. BUILD LABELED INDIVIDUAL + MERGE PANEL
// ----------------------------------------------------------------------------
panelCount = channelCount + 1;
headerHeight = 44;
gap = 8;

// Figure panels are DISPLAY products, not quantitative images.
// Keep the individual TIFFs at full resolution, but use reduced-size
// panel tiles to avoid enormous RAM-heavy montage windows.
panelTileW = imageWidth;
if (panelTileW > 700)
    panelTileW = 700;

panelScale = panelTileW / imageWidth;
panelTileH = round(imageHeight * panelScale);

panelWidth =
    panelCount * panelTileW +
    (panelCount - 1) * gap;

panelHeight =
    panelTileH +
    headerHeight;

newImage(
    "AllChannels_Panel",
    "RGB black",
    panelWidth,
    panelHeight,
    1
);

allPanelWindow = getTitle();

// Paste individual RGB images from disk one at a time.
// This avoids keeping all full-resolution display windows open.
for (c = 0; c < channelCount; c++) {

    individualPNG =
        displayIndividualFolder +
        safeSampleName +
        "_MAX_" +
        makeSafeName(markers[c]) +
        "_" +
        colors[c] +
        ".png";

    open(individualPNG);
    tempPanelSource = getTitle();

    if (imageWidth != panelTileW)
        run("Size...", "width=" + panelTileW + " height=" + panelTileH + " interpolation=Bilinear");

    run("Select All");
    run("Copy");

    selectWindow(allPanelWindow);
    makeRectangle(
        c * (panelTileW + gap),
        headerHeight,
        panelTileW,
        panelTileH
    );
    run("Paste");
    run("Select None");

    drawCenteredLabel(
        markers[c],
        c * (panelTileW + gap),
        panelTileW,
        colors[c],
        18
    );

    selectWindow(tempPanelSource);
    close();
}

// Paste complete merge from the saved PNG.
mergePNG =
    mergeFolder +
    safeSampleName +
    "_MAX_Merge_RGB.png";

open(mergePNG);
tempMergePanelSource = getTitle();

if (imageWidth != panelTileW)
    run("Size...", "width=" + panelTileW + " height=" + panelTileH + " interpolation=Bilinear");

run("Select All");
run("Copy");

selectWindow(allPanelWindow);

mergeX =
    channelCount *
    (panelTileW + gap);

makeRectangle(
    mergeX,
    headerHeight,
    panelTileW,
    panelTileH
);

run("Paste");
run("Select None");

drawCenteredLabel(
    "MERGE",
    mergeX,
    panelTileW,
    "White",
    18
);

selectWindow(tempMergePanelSource);
close();

rename(
    safeSampleName +
    "_MAX_AllChannels_Merge_Panel"
);

allPanelWindow = getTitle();

saveAs(
    "Tiff",
    panelFolder +
    safeSampleName +
    "_MAX_AllChannels_Merge_Panel.tif"
);

saveAs(
    "PNG",
    panelFolder +
    safeSampleName +
    "_MAX_AllChannels_Merge_Panel.png"
);

allPanelWindow = getTitle();

// ----------------------------------------------------------------------------
// 15. CREATE ALL PAIRWISE COMBINATIONS
// ----------------------------------------------------------------------------
pairCount = channelCount * (channelCount - 1) / 2;

pairRGBWindows = newArray(pairCount);
pairRGBPaths = newArray(pairCount);
pairNames = newArray(pairCount);
pairI = newArray(pairCount);
pairJ = newArray(pairCount);

p = 0;

if (channelCount > 1) {

    for (i = 0; i < channelCount - 1; i++) {
        for (j = i + 1; j < channelCount; j++) {

            pairI[p] = i;
            pairJ[p] = j;

            pairNames[p] =
                markers[i] +
                " + " +
                markers[j];

            // Duplicate each RAW max so pair merge is independent.
            selectWindow(maxWindows[i]);
            run(
                "Duplicate...",
                "title=[PAIR_A_" + p + "] duplicate"
            );
            pairA = getTitle();
            applyLUT(colors[i]);
            setMinAndMax(displayMins[i], displayMaxs[i]);

            selectWindow(maxWindows[j]);
            run(
                "Duplicate...",
                "title=[PAIR_B_" + p + "] duplicate"
            );
            pairB = getTitle();
            applyLUT(colors[j]);
            setMinAndMax(displayMins[j], displayMaxs[j]);

            pairMergeOptions =
                "c1=[" + pairA + "] " +
                "c2=[" + pairB + "] create";

            run("Merge Channels...", pairMergeOptions);

            pairComposite = getTitle();

            Stack.setChannel(1);
            applyLUT(colors[i]);
            setMinAndMax(displayMins[i], displayMaxs[i]);

            Stack.setChannel(2);
            applyLUT(colors[j]);
            setMinAndMax(displayMins[j], displayMaxs[j]);

            Stack.setDisplayMode("composite");
            Stack.setActiveChannels("11");

            run("RGB Color");

            pairRGBName =
                safeSampleName +
                "_PAIR_" +
                makeSafeName(markers[i]) +
                "_PLUS_" +
                makeSafeName(markers[j]);

            rename(pairRGBName);
            pairRGBWindows[p] = getTitle();

            saveAs(
                "Tiff",
                pairFolder +
                pairRGBName +
                ".tif"
            );

            pairRGBPaths[p] =
                pairFolder +
                pairRGBName +
                ".png";

            saveAs(
                "PNG",
                pairRGBPaths[p]
            );

            // Pairwise RGB output is now on disk; close immediately.
            close();
            pairRGBWindows[p] = "";

            // Merge Channels with "create" consumes/handles its inputs
            // depending on Fiji version. Close leftovers only if present.
            if (isOpen(pairA)) {
                selectWindow(pairA);
                close();
            }

            if (isOpen(pairB)) {
                selectWindow(pairB);
                close();
            }

            p++;
        }
    }
}

// ----------------------------------------------------------------------------
// 16. CREATE LABELED PAIRWISE SUMMARY PANEL
//
// One row per pair:
//    Marker A | Marker B | A + B
//
// This generalizes the old Macro 4 layout.
// ----------------------------------------------------------------------------
if (pairCount > 0) {

    pairPanelCols = 3;
    pairHeaderHeight = 38;
    rowGap = 10;
    colGap = 8;

    pairTileW = imageWidth;
    if (pairTileW > 700)
        pairTileW = 700;

    pairScale = pairTileW / imageWidth;
    pairTileH = round(imageHeight * pairScale);

    pairPanelWidth =
        pairPanelCols * pairTileW +
        (pairPanelCols - 1) * colGap;

    pairRowHeight =
        pairHeaderHeight +
        pairTileH;

    pairPanelHeight =
        pairCount * pairRowHeight +
        (pairCount - 1) * rowGap;

    newImage(
        "Pairwise_Summary",
        "RGB black",
        pairPanelWidth,
        pairPanelHeight,
        1
    );

    pairPanelWindow = getTitle();

    for (p = 0; p < pairCount; p++) {

        i = pairI[p];
        j = pairJ[p];

        rowY =
            p *
            (pairRowHeight + rowGap);

        // Marker i — reopen only for this row, resize for panel, then close.
        individualPNG_i =
            displayIndividualFolder +
            safeSampleName +
            "_MAX_" +
            makeSafeName(markers[i]) +
            "_" +
            colors[i] +
            ".png";

        open(individualPNG_i);
        tempI = getTitle();

        if (imageWidth != pairTileW)
            run("Size...", "width=" + pairTileW + " height=" + pairTileH + " interpolation=Bilinear");

        run("Select All");
        run("Copy");

        selectWindow(pairPanelWindow);
        makeRectangle(
            0,
            rowY + pairHeaderHeight,
            pairTileW,
            pairTileH
        );
        run("Paste");
        run("Select None");

        drawCenteredLabelAtY(
            markers[i],
            0,
            pairTileW,
            colors[i],
            16,
            rowY + 25
        );

        selectWindow(tempI);
        close();

        // Marker j
        individualPNG_j =
            displayIndividualFolder +
            safeSampleName +
            "_MAX_" +
            makeSafeName(markers[j]) +
            "_" +
            colors[j] +
            ".png";

        open(individualPNG_j);
        tempJ = getTitle();

        if (imageWidth != pairTileW)
            run("Size...", "width=" + pairTileW + " height=" + pairTileH + " interpolation=Bilinear");

        run("Select All");
        run("Copy");

        selectWindow(pairPanelWindow);
        makeRectangle(
            pairTileW + colGap,
            rowY + pairHeaderHeight,
            pairTileW,
            pairTileH
        );
        run("Paste");
        run("Select None");

        drawCenteredLabelAtY(
            markers[j],
            pairTileW + colGap,
            pairTileW,
            colors[j],
            16,
            rowY + 25
        );

        selectWindow(tempJ);
        close();

        // Pair merge — reopen saved PNG, resize for panel, then close.
        open(pairRGBPaths[p]);
        tempPair = getTitle();

        if (imageWidth != pairTileW)
            run("Size...", "width=" + pairTileW + " height=" + pairTileH + " interpolation=Bilinear");

        run("Select All");
        run("Copy");

        selectWindow(pairPanelWindow);
        makeRectangle(
            2 * (pairTileW + colGap),
            rowY + pairHeaderHeight,
            pairTileW,
            pairTileH
        );
        run("Paste");
        run("Select None");

        // Pair label is neutral white because it contains two colors.
        pairLabel = markers[i] + " + " + markers[j];

        drawCenteredLabelAtY(
            pairLabel,
            2 * (pairTileW + colGap),
            pairTileW,
            "White",
            16,
            rowY + 25
        );

        selectWindow(tempPair);
        close();
    }

    rename(
        safeSampleName +
        "_MAX_Pairwise_Summary_Panel"
    );

    pairPanelWindow = getTitle();

    saveAs(
        "Tiff",
        pairPanelFolder +
        safeSampleName +
        "_MAX_Pairwise_Summary_Panel.tif"
    );

    saveAs(
        "PNG",
        pairPanelFolder +
        safeSampleName +
        "_MAX_Pairwise_Summary_Panel.png"
    );

    pairPanelWindow = getTitle();
}

// ----------------------------------------------------------------------------
// 17. SAVE DISPLAY SETTINGS / PROVENANCE
// ----------------------------------------------------------------------------
settingsPath =
    step3Folder +
    safeSampleName +
    "_display_settings.txt";

settings =
    "STEP 3 — FULL-IMAGE MAX PROJECTIONS + FIGURES\n" +
    "===============================================\n\n" +

    "INPUT\n" +
    "Prepared Z-stack: " + inputPath + "\n" +
    "Step 1 channel map: " + step1SummaryPath + "\n\n" +

    "IMAGE STRUCTURE\n" +
    "Width: " + imageWidth + " pixels\n" +
    "Height: " + imageHeight + " pixels\n" +
    "Channels: " + channelCount + "\n" +
    "Z-planes projected: " + sliceCount + "\n" +
    "Projection: Maximum intensity\n\n" +

    "CHANNEL DISPLAY SETTINGS\n";

for (c = 0; c < channelCount; c++) {
    settings = settings +
        "Channel " + (c + 1) + "\n" +
        "Marker: " + markers[c] + "\n" +
        "Display color: " + colors[c] + "\n" +
        "Display minimum: " + d2s(displayMins[c], 6) + "\n" +
        "Display maximum: " + d2s(displayMaxs[c], 6) + "\n\n";
}

settings = settings +
    "OUTPUTS\n" +
    "Raw individual MAX TIFFs: " + rawMaxFolder + "\n" +
    "Display individual images: " + displayIndividualFolder + "\n" +
    "Complete merge: " + mergeFolder + "\n" +
    "Individual + merge panel: " + panelFolder + "\n" +
    "Pairwise combinations: " + pairFolder + "\n" +
    "Pairwise summary panel: " + pairPanelFolder + "\n\n" +

    "PROCESSING NOTES\n" +
    "Raw MAX TIFFs preserve projection pixel values.\n" +
    "Brightness/contrast settings are display-only.\n" +
    "Display-ready RGB TIFF/PNG files have LUT/display appearance baked in.\n" +
    "Marker labels were added only in the figure header area above images.\n" +
    "No ROI was selected in Step 3.\n";

File.saveString(settings, settingsPath);

// Also save a machine-readable display CSV.
csvPath =
    step3Folder +
    safeSampleName +
    "_display_settings.csv";

csv =
    "channel_index,marker,display_color,display_min,display_max\n";

for (c = 0; c < channelCount; c++) {
    csv = csv +
        (c + 1) + "," +
        csvQuote(markers[c]) + "," +
        csvQuote(colors[c]) + "," +
        d2s(displayMins[c], 9) + "," +
        d2s(displayMaxs[c], 9) + "\n";
}

File.saveString(csv, csvPath);

// ----------------------------------------------------------------------------
// 18. CLEAN UP
// ----------------------------------------------------------------------------
closeBC();

// Close summary panels.
if (pairCount > 0) {
    if (isOpen(pairPanelWindow)) {
        selectWindow(pairPanelWindow);
        close();
    }
}

if (isOpen(allPanelWindow)) {
    selectWindow(allPanelWindow);
    close();
}

// Intermediate individual and pairwise RGB windows were already closed
// immediately after saving. Only the editable composite and raw MAX windows
// remain at this point.
if (isOpen(editableCompositeTitle)) {
    selectWindow(editableCompositeTitle);
    close();
}

for (c = 0; c < channelCount; c++) {
    if (isOpen(maxWindows[c])) {
        selectWindow(maxWindows[c]);
        close();
    }
}

if (isOpen(originalTitle)) {
    selectWindow(originalTitle);
    close();
}

// ----------------------------------------------------------------------------
// 19. COMPLETE
// ----------------------------------------------------------------------------
Dialog.create("Step 3 complete");
Dialog.addMessage(
    "Full-image figures were created successfully.\n\n" +
    "CHANNELS\n" +
    markerMapText + "\n" +
    "DISPLAY SETTINGS\n" +
    settingsReview + "\n" +
    "PAIRWISE COMBINATIONS CREATED: " + pairCount + "\n\n" +
    "SAVED IN\n" +
    step3Folder + "\n\n" +
    "NEXT STEP\n" +
    "ROI selection should use the editable MAX composite saved in:\n" +
    mergeFolder + "\n\n" +
    safeSampleName + "_MAX_merged_composite.tif"
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
    s = replace(s, "+", "PLUS");
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

function csvQuote(s) {
    s = replace(s, "\"", "\"\"");
    return "\"" + s + "\"";
}

function defaultColorForMarker(marker, index) {

    m = toLowerCase(marker);

    if (
        indexOf(m, "dapi") >= 0 ||
        indexOf(m, "hoechst") >= 0
    )
        return "Blue";

    // Otherwise give distinct neutral defaults by channel position.
    defaults = newArray(
        "Green",
        "Magenta",
        "Red",
        "Cyan",
        "Yellow"
    );

    return defaults[index];
}

function applyLUT(lutName) {

    if (lutName == "Red")
        run("Red");

    else if (lutName == "Green")
        run("Green");

    else if (lutName == "Blue")
        run("Blue");

    else if (lutName == "Magenta")
        run("Magenta");

    else if (lutName == "Cyan")
        run("Cyan");

    else if (lutName == "Yellow")
        run("Yellow");

    else
        run("Grays");
}

function allChannelsMask(n) {

    mask = "";

    for (k = 0; k < n; k++)
        mask = mask + "1";

    return mask;
}

function labelRGB(colorName) {

    if (colorName == "Red")
        return "255,0,0";

    if (colorName == "Green")
        return "0,255,0";

    if (colorName == "Blue")
        return "0,120,255";

    if (colorName == "Magenta")
        return "255,0,255";

    if (colorName == "Cyan")
        return "0,255,255";

    if (colorName == "Yellow")
        return "255,255,0";

    if (colorName == "White")
        return "255,255,255";

    return "230,230,230";
}

function setLabelColor(colorName) {

    rgb = split(labelRGB(colorName), ",");

    setColor(
        parseInt(rgb[0]),
        parseInt(rgb[1]),
        parseInt(rgb[2])
    );
}

function drawCenteredLabel(text, panelX, panelW, colorName, fontSize) {

    setFont("SansSerif", fontSize, "bold");
    setLabelColor(colorName);

    textW = getStringWidth(text);
    x = panelX + (panelW - textW) / 2;
    y = 28;

    drawString(text, x, y);
}

function drawCenteredLabelAtY(
    text,
    panelX,
    panelW,
    colorName,
    fontSize,
    y
) {

    setFont("SansSerif", fontSize, "bold");
    setLabelColor(colorName);

    textW = getStringWidth(text);
    x = panelX + (panelW - textW) / 2;

    drawString(text, x, y);
}

function closeBC() {
    if (isOpen("B&C"))
        close("B&C");
}

function closeAllStep3Windows(originalTitle, maxWindows, n) {

    closeBC();

    for (q = 0; q < n; q++) {
        if (isOpen(maxWindows[q])) {
            selectWindow(maxWindows[q]);
            close();
        }
    }

    if (isOpen(originalTitle)) {
        selectWindow(originalTitle);
        close();
    }
}
