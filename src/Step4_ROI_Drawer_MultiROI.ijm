// ============================================================================
// STEP 4 — ROI DRAWER + MULTIPLE ROI MANAGER
// Version 1
//
// INPUT:
//   Select the editable MAX composite created by Step 3:
//       *_MAX_merged_composite.tif
//
// PURPOSE:
//   Maintain ZERO, ONE, or MANY rectangular zoom/crop ROIs for one image.
//
// PERSISTENT BEHAVIOR:
//   • If this image already has a saved ROI set, Step 4 loads it.
//   • Add new ROIs.
//   • Delete existing ROIs.
//   • Redraw/revise ROIs.
//   • Rerun Step 4 later and continue editing the same set.
//   • Nothing is committed until "Finish and update outputs".
//
// OUTPUTS:
//   1. Persistent ROI ZIP
//   2. ROI manifest CSV
//   3. Full-field overview with every ROI box + ROI number
//   4. For EACH ROI:
//        - editable cropped multichannel composite
//        - raw individual channel crop TIFFs
//        - display-colored individual TIFF/PNG
//        - full RGB merge TIFF/PNG
//        - labeled individual + merge panel
//        - every pairwise combination TIFF/PNG
//        - labeled pairwise summary panel
//
// DELETED ROIs:
//   Known generated files from old/deleted ROI numbers are deleted.
//   Empty folders may remain, but stale image outputs are removed.
//
// IMPORTANT:
//   • Rectangular ROIs only.
//   • Supports 1–5 channels.
//   • Uses Step 3 marker names, LUT colors, and display ranges.
//   • Labels sit ABOVE microscopy images, not over them.
// ============================================================================

requires("1.53");

// ----------------------------------------------------------------------------
// 0. WELCOME
// ----------------------------------------------------------------------------
Dialog.create("Step 4 — ROI Drawer");
Dialog.addMessage(
    "Step 4 manages zoom/crop regions for ONE image.\n\n" +
    "You can keep ONE ROI or MANY ROIs.\n\n" +
    "If ROIs were saved previously, they will be loaded automatically.\n" +
    "You may add, delete, or redraw ROIs before updating the outputs.\n\n" +
    "Select the editable MAX composite created by Step 3."
);
Dialog.show();

// ----------------------------------------------------------------------------
// 1. SELECT STEP 3 EDITABLE COMPOSITE
// ----------------------------------------------------------------------------
inputPath = File.openDialog(
    "Step 4 — Select *_MAX_merged_composite.tif from Step 3"
);

if (inputPath == "")
    exit("No file was selected.\n\nNothing was changed.");

inputFileName = File.getName(inputPath);
inputFolder = File.getParent(inputPath) + File.separator;
lowerName = toLowerCase(inputFileName);

expectedSuffix = "_MAX_merged_composite";

dotPosition = lastIndexOf(inputFileName, ".");
if (dotPosition > 0)
    fileBase = substring(inputFileName, 0, dotPosition);
else
    fileBase = inputFileName;

if (!endsWith(lowerName, ".tif") && !endsWith(lowerName, ".tiff"))
    exit("Step 4 expects the editable TIFF created by Step 3.");

if (!endsWith(fileBase, expectedSuffix))
    exit(
        "This does not look like the Step 3 editable MAX composite.\n\n" +
        "Expected a filename ending in:\n" +
        "_MAX_merged_composite.tif"
    );

safeSampleName =
    substring(
        fileBase,
        0,
        lengthOf(fileBase) - lengthOf(expectedSuffix)
    );

// Input:
// analysis/02_max_projection_and_figures/02_complete_merge/file.tif
step3Folder = File.getParent(inputFolder) + File.separator;
analysisFolder = File.getParent(step3Folder) + File.separator;

displaySettingsPath =
    step3Folder +
    safeSampleName +
    "_display_settings.txt";

fullMergePath =
    inputFolder +
    safeSampleName +
    "_MAX_Merge_RGB.png";

if (!File.exists(displaySettingsPath))
    exit(
        "Step 3 display settings were not found.\n\n" +
        "Expected:\n" + displaySettingsPath
    );

if (!File.exists(fullMergePath))
    exit(
        "The Step 3 full RGB merge was not found.\n\n" +
        "Expected:\n" + fullMergePath
    );

// ----------------------------------------------------------------------------
// 2. READ STEP 3 MARKERS / COLORS / DISPLAY RANGES
// ----------------------------------------------------------------------------
settingsText = File.openAsString(displaySettingsPath);
settingsLines = split(settingsText, "\n");

markers = newArray(5);
colors = newArray(5);
displayMins = newArray(5);
displayMaxs = newArray(5);

channelCount = 0;
currentChannel = -1;

for (i = 0; i < settingsLines.length; i++) {

    line = replace(settingsLines[i], "\r", "");

    if (startsWith(line, "Channel ") && indexOf(line, "CHANNEL DISPLAY") < 0) {
        maybeNum = substring(line, lengthOf("Channel "));
        maybeNum = trimString(maybeNum);

        if (matches(maybeNum, "^[1-5]$")) {
            currentChannel = parseInt(maybeNum) - 1;

            if (currentChannel + 1 > channelCount)
                channelCount = currentChannel + 1;
        }
    }

    if (currentChannel >= 0) {

        if (startsWith(line, "Marker:"))
            markers[currentChannel] =
                trimString(substring(line, lengthOf("Marker:")));

        if (startsWith(line, "Display color:"))
            colors[currentChannel] =
                trimString(substring(line, lengthOf("Display color:")));

        if (startsWith(line, "Display minimum:"))
            displayMins[currentChannel] =
                parseFloat(
                    trimString(
                        substring(line, lengthOf("Display minimum:"))
                    )
                );

        if (startsWith(line, "Display maximum:"))
            displayMaxs[currentChannel] =
                parseFloat(
                    trimString(
                        substring(line, lengthOf("Display maximum:"))
                    )
                );
    }
}

if (channelCount < 1 || channelCount > 5)
    exit(
        "Step 4 could not reliably read the Step 3 channel settings.\n\n" +
        "Please inspect:\n" + displaySettingsPath
    );

markerMapText = "";
for (c = 0; c < channelCount; c++) {

    if (markers[c] == "" || colors[c] == "")
        exit(
            "Step 4 found incomplete Step 3 settings for Channel " +
            (c + 1) + "."
        );

    markerMapText =
        markerMapText +
        "Channel " + (c + 1) +
        "  →  " + markers[c] +
        "  (" + colors[c] + ")\n";
}

// ----------------------------------------------------------------------------
// 3. CREATE / DEFINE STEP 4 FOLDERS
// ----------------------------------------------------------------------------
step4Folder =
    analysisFolder +
    "03_ROI_analysis" +
    File.separator;

roiSetFolder =
    step4Folder +
    "00_ROI_set" +
    File.separator;

overviewFolder =
    step4Folder +
    "01_overview" +
    File.separator;

cropRootFolder =
    step4Folder +
    "02_ROI_outputs" +
    File.separator;

File.makeDirectory(step4Folder);
File.makeDirectory(roiSetFolder);
File.makeDirectory(overviewFolder);
File.makeDirectory(cropRootFolder);

roiZipPath =
    roiSetFolder +
    safeSampleName +
    "_ROIs.zip";

roiManifestPath =
    roiSetFolder +
    safeSampleName +
    "_ROI_manifest.csv";

overviewTiffPath =
    overviewFolder +
    safeSampleName +
    "_ROI_overview.tif";

overviewPNGPath =
    overviewFolder +
    safeSampleName +
    "_ROI_overview.png";

// Determine previous ROI count from manifest, if present.
previousROICount = 0;

if (File.exists(roiManifestPath)) {
    oldManifest = File.openAsString(roiManifestPath);
    oldLines = split(oldManifest, "\n");

    // Header is line 0; count non-empty data lines.
    for (i = 1; i < oldLines.length; i++) {
        if (trimString(replace(oldLines[i], "\r", "")) != "")
            previousROICount++;
    }
}

// ----------------------------------------------------------------------------
// 4. OPEN EDITABLE COMPOSITE + VERIFY
// ----------------------------------------------------------------------------
open(inputPath);

if (nImages == 0)
    exit("The editable MAX composite could not be opened.");

originalTitle = getTitle();

getDimensions(
    imageWidth,
    imageHeight,
    actualChannels,
    sliceCount,
    frameCount
);

if (actualChannels != channelCount) {
    close();
    exit(
        "CHANNEL COUNT DOES NOT MATCH STEP 3 SETTINGS.\n\n" +
        "Composite contains: " + actualChannels + "\n" +
        "Step 3 settings contain: " + channelCount
    );
}

if (sliceCount != 1) {
    close();
    exit(
        "Step 4 expects the MAX-projected composite from Step 3.\n\n" +
        "The selected image contains " + sliceCount + " slices."
    );
}

// Restore Step 3 display settings.
for (c = 0; c < channelCount; c++) {
    Stack.setChannel(c + 1);
    applyLUT(colors[c]);
    setMinAndMax(displayMins[c], displayMaxs[c]);
}

Stack.setDisplayMode("composite");
Stack.setActiveChannels(allChannelsMask(channelCount));

// ----------------------------------------------------------------------------
// 5. INITIALIZE ROI MANAGER + LOAD EXISTING ROI SET
// ----------------------------------------------------------------------------
roiManager("Reset");

existingLoaded = 0;

if (File.exists(roiZipPath)) {

    roiManager("Open", roiZipPath);

    loadedCount = roiManager("count");

    if (loadedCount > 0)
        existingLoaded = 1;
}

normalizeROINames();

roiCount = roiManager("count");

if (roiCount > 0)
    roiManager("Show All with labels");

Dialog.create("Step 4 — ROI set ready");

if (existingLoaded)
    statusText =
        "Existing ROI set loaded: " + roiCount + " ROI(s).";
else
    statusText =
        "No previous ROI set was found. Starting a new ROI set.";

Dialog.addMessage(
    statusText + "\n\n" +
    "IMAGE\n" +
    safeSampleName + "\n\n" +
    "CHANNELS\n" +
    markerMapText + "\n" +
    "Next you can add, delete, or redraw ROIs."
);

Dialog.show();

// ----------------------------------------------------------------------------
// 6. INTERACTIVE ROI MANAGEMENT LOOP
// ----------------------------------------------------------------------------
finished = 0;
cancelled = 0;

while (finished == 0 && cancelled == 0) {

    roiCount = roiManager("count");

    Dialog.create("Step 4 — ROI Drawer");

    Dialog.addMessage(
        "Current ROI count: " + roiCount + "\n\n" +
        "ROIs are not permanently changed until you choose\n" +
        "\"Finish and update outputs\"."
    );

    actions = newArray(
        "Add a new ROI",
        "Redraw an existing ROI",
        "Delete an ROI",
        "Inspect current ROIs",
        "Finish and update outputs",
        "Cancel without saving changes"
    );

    Dialog.addChoice("What would you like to do?", actions, "Add a new ROI");
    Dialog.show();

    action = Dialog.getChoice();

    // ------------------------------------------------------------------------
    // ADD
    // ------------------------------------------------------------------------
    if (action == "Add a new ROI") {

        addDone = 0;

        while (addDone == 0) {

            selectWindow(originalTitle);
            roiManager("Show All with labels");
            setTool("rectangle");

            waitForUser(
                "Step 4 — Draw new ROI",
                "Draw a RECTANGULAR ROI on the image.\n\n" +
                "Resize and reposition it until it looks correct.\n\n" +
                "Existing ROIs remain visible for reference.\n\n" +
                "Click OK when the NEW rectangle is ready."
            );

            if (selectionType == -1) {

                Dialog.create("No ROI detected");
                Dialog.addMessage(
                    "No active rectangle was detected.\n\n" +
                    "You can try again or return to the ROI menu."
                );
                noROIChoices = newArray(
                    "Try again",
                    "Return to ROI menu"
                );
                Dialog.addChoice("Next action:", noROIChoices, "Try again");
                Dialog.show();

                if (Dialog.getChoice() == "Return to ROI menu")
                    addDone = 1;

            } else if (selectionType != 0) {

                Dialog.create("Rectangle required");
                Dialog.addMessage(
                    "Step 4 uses rectangular ROIs so every ROI can be saved\n" +
                    "as a reproducible image crop."
                );
                Dialog.show();

            } else {

                getSelectionBounds(
                    newX,
                    newY,
                    newW,
                    newH
                );

                if (newW < 2 || newH < 2) {

                    Dialog.create("ROI too small");
                    Dialog.addMessage("Please draw a larger rectangle.");
                    Dialog.show();

                } else {

                    Dialog.create("Review new ROI");
                    Dialog.addMessage(
                        "Candidate ROI\n\n" +
                        "X: " + newX + "\n" +
                        "Y: " + newY + "\n" +
                        "Width: " + newW + "\n" +
                        "Height: " + newH
                    );

                    addChoices = newArray(
                        "Keep this ROI",
                        "Redraw it",
                        "Discard it"
                    );

                    Dialog.addChoice(
                        "Next action:",
                        addChoices,
                        "Keep this ROI"
                    );

                    Dialog.show();

                    addChoice = Dialog.getChoice();

                    if (addChoice == "Keep this ROI") {

                        selectWindow(originalTitle);
                        roiManager("Add");
                        normalizeROINames();
                        roiManager("Show All with labels");
                        run("Select None");
                        addDone = 1;
                    }

                    if (addChoice == "Discard it") {
                        selectWindow(originalTitle);
                        run("Select None");
                        addDone = 1;
                    }

                    // "Redraw it" loops automatically.
                }
            }
        }
    }

    // ------------------------------------------------------------------------
    // REDRAW EXISTING
    // ------------------------------------------------------------------------
    if (action == "Redraw an existing ROI") {

        roiCount = roiManager("count");

        if (roiCount < 1) {

            Dialog.create("No ROIs to redraw");
            Dialog.addMessage("Add an ROI first.");
            Dialog.show();

        } else {

            roiChoices = makeROIChoiceArray(roiCount);

            Dialog.create("Choose ROI to redraw");
            Dialog.addChoice("ROI:", roiChoices, roiChoices[0]);
            Dialog.show();

            chosenText = Dialog.getChoice();
            chosenIndex = roiChoiceIndex(chosenText, roiCount);

            if (chosenIndex >= 0) {

                selectWindow(originalTitle);
                roiManager("Select", chosenIndex);

                waitForUser(
                    "Step 4 — Redraw " + roiChoices[chosenIndex],
                    "The selected ROI is active.\n\n" +
                    "Move/resize it, OR draw a completely new rectangle.\n\n" +
                    "Click OK when the replacement ROI is ready."
                );

                if (selectionType == 0) {

                    getSelectionBounds(
                        rx,
                        ry,
                        rw,
                        rh
                    );

                    Dialog.create("Review replacement ROI");
                    Dialog.addMessage(
                        roiChoices[chosenIndex] + "\n\n" +
                        "X: " + rx + "\n" +
                        "Y: " + ry + "\n" +
                        "Width: " + rw + "\n" +
                        "Height: " + rh
                    );

                    redrawChoices = newArray(
                        "Use this replacement",
                        "Keep the old ROI"
                    );

                    Dialog.addChoice(
                        "Next action:",
                        redrawChoices,
                        "Use this replacement"
                    );
                    Dialog.show();

                    redrawDecision = Dialog.getChoice();

                    if (redrawDecision == "Use this replacement") {

                        // Add replacement, then delete old ROI.
                        selectWindow(originalTitle);
                        roiManager("Add");

                        // The replacement is now at end.
                        newIndex = roiManager("count") - 1;

                        // Delete old ROI.
                        roiManager("Select", chosenIndex);
                        roiManager("Delete");

                        normalizeROINames();
                        roiManager("Show All with labels");
                        run("Select None");
                    }

                } else {

                    Dialog.create("Replacement not accepted");
                    Dialog.addMessage(
                        "A rectangular ROI was not detected.\n\n" +
                        "The existing ROI was kept."
                    );
                    Dialog.show();
                }
            }
        }
    }

    // ------------------------------------------------------------------------
    // DELETE
    // ------------------------------------------------------------------------
    if (action == "Delete an ROI") {

        roiCount = roiManager("count");

        if (roiCount < 1) {

            Dialog.create("No ROIs to delete");
            Dialog.addMessage("There are currently no ROIs.");
            Dialog.show();

        } else {

            roiChoices = makeROIChoiceArray(roiCount);

            Dialog.create("Choose ROI to delete");
            Dialog.addChoice("ROI:", roiChoices, roiChoices[0]);
            Dialog.show();

            chosenText = Dialog.getChoice();
            chosenIndex = roiChoiceIndex(chosenText, roiCount);

            if (chosenIndex >= 0) {

                selectWindow(originalTitle);
                roiManager("Select", chosenIndex);

                waitForUser(
                    "Step 4 — Inspect ROI before deletion",
                    roiChoices[chosenIndex] +
                    " is selected on the image.\n\n" +
                    "Inspect it, then click OK."
                );

                Dialog.create("Confirm deletion");
                Dialog.addMessage(
                    "Delete " + roiChoices[chosenIndex] + "?\n\n" +
                    "Its generated outputs will also be removed when you finish."
                );
                Dialog.addCheckbox("Yes — delete this ROI.", false);
                Dialog.show();

                if (Dialog.getCheckbox()) {
                    roiManager("Select", chosenIndex);
                    roiManager("Delete");
                    normalizeROINames();

                    if (roiManager("count") > 0)
                        roiManager("Show All with labels");

                    selectWindow(originalTitle);
                    run("Select None");
                }
            }
        }
    }

    // ------------------------------------------------------------------------
    // INSPECT
    // ------------------------------------------------------------------------
    if (action == "Inspect current ROIs") {

        roiCount = roiManager("count");

        selectWindow(originalTitle);

        if (roiCount > 0)
            roiManager("Show All with labels");

        waitForUser(
            "Step 4 — Inspect ROI set",
            "Current ROI count: " + roiCount + "\n\n" +
            "Inspect the image freely.\n" +
            "You may zoom/pan and switch channels.\n\n" +
            "Click OK to return to the ROI menu."
        );
    }

    // ------------------------------------------------------------------------
    // FINISH
    // ------------------------------------------------------------------------
    if (action == "Finish and update outputs") {

        roiCount = roiManager("count");

        Dialog.create("Step 4 — Final ROI set");
        Dialog.addMessage(
            "Current ROI count: " + roiCount + "\n\n" +
            "If you continue, this becomes the saved ROI set for this image.\n\n" +
            "All ROI figures will be regenerated to match the current set.\n" +
            "Outputs belonging to deleted ROI numbers will be removed."
        );
        Dialog.addCheckbox("Yes — save this ROI set and update outputs.", false);
        Dialog.show();

        if (Dialog.getCheckbox())
            finished = 1;
    }

    // ------------------------------------------------------------------------
    // CANCEL
    // ------------------------------------------------------------------------
    if (action == "Cancel without saving changes") {

        Dialog.create("Cancel Step 4?");
        Dialog.addMessage(
            "Any ROI changes made during THIS run will be discarded.\n\n" +
            "The previously saved ROI set and outputs will remain unchanged."
        );
        Dialog.addCheckbox("Yes — cancel without saving.", false);
        Dialog.show();

        if (Dialog.getCheckbox())
            cancelled = 1;
    }
}

// ----------------------------------------------------------------------------
// 7. CANCEL CLEANLY
// ----------------------------------------------------------------------------
if (cancelled == 1) {

    roiManager("Reset");

    if (isOpen(originalTitle)) {
        selectWindow(originalTitle);
        close();
    }

    exit(
        "Step 4 cancelled.\n\n" +
        "The previously saved ROI set and outputs were not changed."
    );
}

// ----------------------------------------------------------------------------
// 8. NORMALIZE + SAVE CURRENT ROI SET
// ----------------------------------------------------------------------------
normalizeROINames();

roiCount = roiManager("count");

// Remove old ROI ZIP first so an empty set can be represented cleanly.
if (File.exists(roiZipPath))
    File.delete(roiZipPath);

if (roiCount > 0)
    roiManager("Save", roiZipPath);

// Manifest
manifest =
    "roi_index,roi_name,x,y,width,height\n";

for (r = 0; r < roiCount; r++) {

    selectWindow(originalTitle);
    roiManager("Select", r);

    getSelectionBounds(
        mx,
        my,
        mw,
        mh
    );

    manifest =
        manifest +
        (r + 1) + "," +
        csvQuote(roiLabel(r + 1)) + "," +
        mx + "," +
        my + "," +
        mw + "," +
        mh + "\n";
}

File.saveString(manifest, roiManifestPath);

// ----------------------------------------------------------------------------
// 9. DELETE KNOWN STALE OUTPUT FILES
//
// Clear outputs for all ROI numbers that existed previously OR exist now.
// Current outputs will then be rebuilt cleanly.
// ----------------------------------------------------------------------------
maxCleanupCount = previousROICount;
if (roiCount > maxCleanupCount)
    maxCleanupCount = roiCount;

for (r = 1; r <= maxCleanupCount; r++)
    deleteKnownROIOutputs(r);

// ----------------------------------------------------------------------------
// 10. CREATE FULL OVERVIEW WITH ALL CURRENT ROIs
// ----------------------------------------------------------------------------
open(fullMergePath);
overviewSource = getTitle();

rename("ROI_Overview_Work");
overviewWork = getTitle();

setFont("SansSerif", 18, "bold");

for (r = 0; r < roiCount; r++) {

    selectWindow(originalTitle);
    roiManager("Select", r);

    getSelectionBounds(
        ox,
        oy,
        ow,
        oh
    );

    selectWindow(overviewWork);

    setColor(255, 255, 255);
    setLineWidth(3);
    drawRect(ox, oy, ow, oh);

    labelText = roiLabel(r + 1);

    labelX = ox + 5;
    labelY = oy + 22;

    // Draw black background behind ROI label for readability.
    setColor(0, 0, 0);
    fillRect(
        labelX - 3,
        labelY - 18,
        getStringWidth(labelText) + 6,
        22
    );

    setColor(255, 255, 255);
    drawString(labelText, labelX, labelY);
}

saveAs("Tiff", overviewTiffPath);
saveAs("PNG", overviewPNGPath);

close();

// ----------------------------------------------------------------------------
// 11. GENERATE OUTPUTS FOR EACH CURRENT ROI
// ----------------------------------------------------------------------------
for (r = 0; r < roiCount; r++) {

    roiNumber = r + 1;
    roiName = roiLabel(roiNumber);

    roiFolder =
        cropRootFolder +
        roiName +
        File.separator;

    File.makeDirectory(roiFolder);

    // ------------------------------------------------------------------------
    // 11A. CROP EDITABLE MULTICHANNEL COMPOSITE
    // ------------------------------------------------------------------------
    selectWindow(originalTitle);
    roiManager("Select", r);

    getSelectionBounds(
        roiX,
        roiY,
        roiW,
        roiH
    );

    run(
        "Duplicate...",
        "title=[" + roiName + "_Composite_Work] duplicate"
    );

    cropComposite = getTitle();

    // Restore Step 3 display state.
    for (c = 0; c < channelCount; c++) {
        Stack.setChannel(c + 1);
        applyLUT(colors[c]);
        setMinAndMax(displayMins[c], displayMaxs[c]);
    }

    Stack.setDisplayMode("composite");
    Stack.setActiveChannels(allChannelsMask(channelCount));

    editableCropPath =
        roiFolder +
        safeSampleName +
        "_" +
        roiName +
        "_editable_composite.tif";

    saveAs("Tiff", editableCropPath);
    cropComposite = getTitle();

    // ------------------------------------------------------------------------
    // 11B. SPLIT CROP + SAVE INDIVIDUAL CHANNEL OUTPUTS
    // ------------------------------------------------------------------------
    selectWindow(cropComposite);
    run("Split Channels");

    cropChannelWindows = newArray(channelCount);
    cropRawPaths = newArray(channelCount);
    cropDisplayPNGPaths = newArray(channelCount);

    for (c = 0; c < channelCount; c++) {

        cropChannelWindows[c] =
            "C" + (c + 1) + "-" + cropComposite;

        if (!isOpen(cropChannelWindows[c]))
            exit(
                "Could not locate Channel " + (c + 1) +
                " while generating " + roiName + "."
            );

        selectWindow(cropChannelWindows[c]);

        markerSafe = makeSafeName(markers[c]);

        rawPath =
            roiFolder +
            safeSampleName +
            "_" +
            roiName +
            "_" +
            markerSafe +
            "_raw.tif";

        cropRawPaths[c] = rawPath;
        saveAs("Tiff", rawPath);
        cropChannelWindows[c] = getTitle();

        // Display copy
        run(
            "Duplicate...",
            "title=[" + roiName + "_" + markerSafe + "_Display] duplicate"
        );

        applyLUT(colors[c]);
        setMinAndMax(displayMins[c], displayMaxs[c]);
        run("RGB Color");

        displayTiffPath =
            roiFolder +
            safeSampleName +
            "_" +
            roiName +
            "_" +
            markerSafe +
            "_" +
            colors[c] +
            ".tif";

        displayPNGPath =
            roiFolder +
            safeSampleName +
            "_" +
            roiName +
            "_" +
            markerSafe +
            "_" +
            colors[c] +
            ".png";

        cropDisplayPNGPaths[c] = displayPNGPath;

        saveAs("Tiff", displayTiffPath);
        saveAs("PNG", displayPNGPath);
        close();
    }

    // ------------------------------------------------------------------------
    // 11C. BUILD EDITABLE CROP MERGE FROM RAW CHANNEL CROPS
    // ------------------------------------------------------------------------
    mergeOptions = "";

    for (c = 0; c < channelCount; c++)
        mergeOptions =
            mergeOptions +
            "c" + (c + 1) +
            "=[" + cropChannelWindows[c] + "] ";

    mergeOptions = mergeOptions + "create keep";

    run("Merge Channels...", mergeOptions);

    roiMergedComposite = getTitle();

    for (c = 0; c < channelCount; c++) {
        Stack.setChannel(c + 1);
        applyLUT(colors[c]);
        setMinAndMax(displayMins[c], displayMaxs[c]);
    }

    Stack.setDisplayMode("composite");
    Stack.setActiveChannels(allChannelsMask(channelCount));

    run(
        "Duplicate...",
        "title=[" + roiName + "_Merge_RGB] duplicate"
    );

    Stack.setDisplayMode("composite");
    Stack.setActiveChannels(allChannelsMask(channelCount));
    run("RGB Color");

    roiMergeRGB = getTitle();

    roiMergeTiffPath =
        roiFolder +
        safeSampleName +
        "_" +
        roiName +
        "_Merge_RGB.tif";

    roiMergePNGPath =
        roiFolder +
        safeSampleName +
        "_" +
        roiName +
        "_Merge_RGB.png";

    saveAs("Tiff", roiMergeTiffPath);
    saveAs("PNG", roiMergePNGPath);
    close();

    // ------------------------------------------------------------------------
    // 11D. LABELED INDIVIDUAL + MERGE PANEL
    // ------------------------------------------------------------------------
    tileW = roiW;
    if (tileW > 700)
        tileW = 700;

    tileScale = tileW / roiW;
    tileH = round(roiH * tileScale);

    headerH = 44;
    gap = 8;
    panelCount = channelCount + 1;

    panelW =
        panelCount * tileW +
        (panelCount - 1) * gap;

    panelH =
        headerH +
        tileH;

    newImage(
        roiName + "_AllChannels_Panel",
        "RGB black",
        panelW,
        panelH,
        1
    );

    roiPanelWindow = getTitle();

    for (c = 0; c < channelCount; c++) {

        open(cropDisplayPNGPaths[c]);
        tempTile = getTitle();

        getDimensions(tw, th, tc, tz, tt);

        if (tw != tileW || th != tileH)
            run(
                "Size...",
                "width=" + tileW +
                " height=" + tileH +
                " interpolation=Bilinear"
            );

        run("Select All");
        run("Copy");

        selectWindow(roiPanelWindow);

        makeRectangle(
            c * (tileW + gap),
            headerH,
            tileW,
            tileH
        );

        run("Paste");
        run("Select None");

        drawCenteredLabel(
            markers[c],
            c * (tileW + gap),
            tileW,
            colors[c],
            18
        );

        selectWindow(tempTile);
        close();
    }

    // Merge tile
    open(roiMergePNGPath);
    tempMergeTile = getTitle();

    getDimensions(mw0, mh0, mc0, mz0, mt0);

    if (mw0 != tileW || mh0 != tileH)
        run(
            "Size...",
            "width=" + tileW +
            " height=" + tileH +
            " interpolation=Bilinear"
        );

    run("Select All");
    run("Copy");

    selectWindow(roiPanelWindow);

    mergeX =
        channelCount *
        (tileW + gap);

    makeRectangle(
        mergeX,
        headerH,
        tileW,
        tileH
    );

    run("Paste");
    run("Select None");

    drawCenteredLabel(
        "MERGE",
        mergeX,
        tileW,
        "White",
        18
    );

    selectWindow(tempMergeTile);
    close();

    panelTiff =
        roiFolder +
        safeSampleName +
        "_" +
        roiName +
        "_AllChannels_Merge_Panel.tif";

    panelPNG =
        roiFolder +
        safeSampleName +
        "_" +
        roiName +
        "_AllChannels_Merge_Panel.png";

    selectWindow(roiPanelWindow);
    saveAs("Tiff", panelTiff);
    saveAs("PNG", panelPNG);
    close();

    // ------------------------------------------------------------------------
    // 11E. ALL PAIRWISE COMBINATIONS
    // ------------------------------------------------------------------------
    pairCount = channelCount * (channelCount - 1) / 2;

    pairPaths = newArray(pairCount);
    pairI = newArray(pairCount);
    pairJ = newArray(pairCount);

    p = 0;

    if (channelCount > 1) {

        for (i = 0; i < channelCount - 1; i++) {
            for (j = i + 1; j < channelCount; j++) {

                pairI[p] = i;
                pairJ[p] = j;

                selectWindow(cropChannelWindows[i]);
                run(
                    "Duplicate...",
                    "title=[ROI_PAIR_A_" + p + "] duplicate"
                );

                pairA = getTitle();
                applyLUT(colors[i]);
                setMinAndMax(displayMins[i], displayMaxs[i]);

                selectWindow(cropChannelWindows[j]);
                run(
                    "Duplicate...",
                    "title=[ROI_PAIR_B_" + p + "] duplicate"
                );

                pairB = getTitle();
                applyLUT(colors[j]);
                setMinAndMax(displayMins[j], displayMaxs[j]);

                pairOptions =
                    "c1=[" + pairA + "] " +
                    "c2=[" + pairB + "] create";

                run("Merge Channels...", pairOptions);

                Stack.setChannel(1);
                applyLUT(colors[i]);
                setMinAndMax(displayMins[i], displayMaxs[i]);

                Stack.setChannel(2);
                applyLUT(colors[j]);
                setMinAndMax(displayMins[j], displayMaxs[j]);

                Stack.setDisplayMode("composite");
                Stack.setActiveChannels("11");
                run("RGB Color");

                pairBase =
                    safeSampleName +
                    "_" +
                    roiName +
                    "_PAIR_" +
                    makeSafeName(markers[i]) +
                    "_PLUS_" +
                    makeSafeName(markers[j]);

                pairTiffPath =
                    roiFolder +
                    pairBase +
                    ".tif";

                pairPNGPath =
                    roiFolder +
                    pairBase +
                    ".png";

                pairPaths[p] = pairPNGPath;

                saveAs("Tiff", pairTiffPath);
                saveAs("PNG", pairPNGPath);
                close();

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

    // ------------------------------------------------------------------------
    // 11F. PAIRWISE SUMMARY PANEL
    // ------------------------------------------------------------------------
    if (pairCount > 0) {

        pairTileW = roiW;
        if (pairTileW > 700)
            pairTileW = 700;

        pairScale = pairTileW / roiW;
        pairTileH = round(roiH * pairScale);

        pairHeaderH = 38;
        colGap = 8;
        rowGap = 10;

        pairPanelW =
            3 * pairTileW +
            2 * colGap;

        pairRowH =
            pairHeaderH +
            pairTileH;

        pairPanelH =
            pairCount * pairRowH +
            (pairCount - 1) * rowGap;

        newImage(
            roiName + "_Pairwise_Summary",
            "RGB black",
            pairPanelW,
            pairPanelH,
            1
        );

        pairPanelWindow = getTitle();

        for (p = 0; p < pairCount; p++) {

            i = pairI[p];
            j = pairJ[p];

            rowY =
                p *
                (pairRowH + rowGap);

            // Marker i
            open(cropDisplayPNGPaths[i]);
            tempI = getTitle();

            getDimensions(iw0, ih0, ic0, iz0, it0);

            if (iw0 != pairTileW || ih0 != pairTileH)
                run(
                    "Size...",
                    "width=" + pairTileW +
                    " height=" + pairTileH +
                    " interpolation=Bilinear"
                );

            run("Select All");
            run("Copy");

            selectWindow(pairPanelWindow);
            makeRectangle(
                0,
                rowY + pairHeaderH,
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
            open(cropDisplayPNGPaths[j]);
            tempJ = getTitle();

            getDimensions(jw0, jh0, jc0, jz0, jt0);

            if (jw0 != pairTileW || jh0 != pairTileH)
                run(
                    "Size...",
                    "width=" + pairTileW +
                    " height=" + pairTileH +
                    " interpolation=Bilinear"
                );

            run("Select All");
            run("Copy");

            selectWindow(pairPanelWindow);
            makeRectangle(
                pairTileW + colGap,
                rowY + pairHeaderH,
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

            // Pair
            open(pairPaths[p]);
            tempPair = getTitle();

            getDimensions(pw0, ph0, pc0, pz0, pt0);

            if (pw0 != pairTileW || ph0 != pairTileH)
                run(
                    "Size...",
                    "width=" + pairTileW +
                    " height=" + pairTileH +
                    " interpolation=Bilinear"
                );

            run("Select All");
            run("Copy");

            selectWindow(pairPanelWindow);
            makeRectangle(
                2 * (pairTileW + colGap),
                rowY + pairHeaderH,
                pairTileW,
                pairTileH
            );
            run("Paste");
            run("Select None");

            pairLabel =
                markers[i] +
                " + " +
                markers[j];

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

        pairPanelTiff =
            roiFolder +
            safeSampleName +
            "_" +
            roiName +
            "_Pairwise_Summary_Panel.tif";

        pairPanelPNG =
            roiFolder +
            safeSampleName +
            "_" +
            roiName +
            "_Pairwise_Summary_Panel.png";

        selectWindow(pairPanelWindow);
        saveAs("Tiff", pairPanelTiff);
        saveAs("PNG", pairPanelPNG);
        close();
    }

    // ------------------------------------------------------------------------
    // 11G. CLOSE ROI INTERMEDIATE WINDOWS
    // ------------------------------------------------------------------------
    if (isOpen(roiMergedComposite)) {
        selectWindow(roiMergedComposite);
        close();
    }

    if (isOpen(cropComposite)) {
        selectWindow(cropComposite);
        close();
    }

    for (c = 0; c < channelCount; c++) {
        if (isOpen(cropChannelWindows[c])) {
            selectWindow(cropChannelWindows[c]);
            close();
        }
    }
}

// ----------------------------------------------------------------------------
// 12. CLEAN UP MAIN IMAGE
// ----------------------------------------------------------------------------
roiManager("Reset");

if (isOpen(originalTitle)) {
    selectWindow(originalTitle);
    close();
}

// ----------------------------------------------------------------------------
// 13. COMPLETE
// ----------------------------------------------------------------------------
Dialog.create("Step 4 complete");
Dialog.addMessage(
    "ROI set updated successfully.\n\n" +
    "CURRENT ROI COUNT: " + roiCount + "\n\n" +
    "Saved ROI set:\n" +
    roiZipPath + "\n\n" +
    "ROI overview:\n" +
    overviewPNGPath + "\n\n" +
    "ROI outputs:\n" +
    cropRootFolder + "\n\n" +
    "You can rerun Step 4 later on the SAME Step 3 composite to\n" +
    "add, delete, or redraw ROIs."
);
Dialog.show();


// ============================================================================
// FUNCTIONS
// ============================================================================

function normalizeROINames() {

    n = roiManager("count");

    for (q = 0; q < n; q++) {
        roiManager("Select", q);
        roiManager("Rename", roiLabel(q + 1));
    }
}

function roiLabel(n) {

    if (n < 10)
        return "ROI_0" + n;

    return "ROI_" + n;
}

function makeROIChoiceArray(n) {

    arr = newArray(n);

    for (q = 0; q < n; q++)
        arr[q] = roiLabel(q + 1);

    return arr;
}

function roiChoiceIndex(choiceText, n) {

    for (q = 0; q < n; q++) {
        if (choiceText == roiLabel(q + 1))
            return q;
    }

    return -1;
}

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

    for (q = 0; q < n; q++)
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

function drawCenteredLabel(
    text,
    panelX,
    panelW,
    colorName,
    fontSize
) {

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

function deleteKnownROIOutputs(roiNumber) {

    roiName = roiLabel(roiNumber);

    roiFolder =
        cropRootFolder +
        roiName +
        File.separator;

    // Common ROI outputs.
    deleteIfExists(
        roiFolder +
        safeSampleName +
        "_" +
        roiName +
        "_editable_composite.tif"
    );

    deleteIfExists(
        roiFolder +
        safeSampleName +
        "_" +
        roiName +
        "_Merge_RGB.tif"
    );

    deleteIfExists(
        roiFolder +
        safeSampleName +
        "_" +
        roiName +
        "_Merge_RGB.png"
    );

    deleteIfExists(
        roiFolder +
        safeSampleName +
        "_" +
        roiName +
        "_AllChannels_Merge_Panel.tif"
    );

    deleteIfExists(
        roiFolder +
        safeSampleName +
        "_" +
        roiName +
        "_AllChannels_Merge_Panel.png"
    );

    deleteIfExists(
        roiFolder +
        safeSampleName +
        "_" +
        roiName +
        "_Pairwise_Summary_Panel.tif"
    );

    deleteIfExists(
        roiFolder +
        safeSampleName +
        "_" +
        roiName +
        "_Pairwise_Summary_Panel.png"
    );

    // Individual channels.
    for (dc = 0; dc < channelCount; dc++) {

        markerSafe = makeSafeName(markers[dc]);

        deleteIfExists(
            roiFolder +
            safeSampleName +
            "_" +
            roiName +
            "_" +
            markerSafe +
            "_raw.tif"
        );

        deleteIfExists(
            roiFolder +
            safeSampleName +
            "_" +
            roiName +
            "_" +
            markerSafe +
            "_" +
            colors[dc] +
            ".tif"
        );

        deleteIfExists(
            roiFolder +
            safeSampleName +
            "_" +
            roiName +
            "_" +
            markerSafe +
            "_" +
            colors[dc] +
            ".png"
        );
    }

    // Pairwise files.
    if (channelCount > 1) {

        for (di = 0; di < channelCount - 1; di++) {
            for (dj = di + 1; dj < channelCount; dj++) {

                pairBase =
                    safeSampleName +
                    "_" +
                    roiName +
                    "_PAIR_" +
                    makeSafeName(markers[di]) +
                    "_PLUS_" +
                    makeSafeName(markers[dj]);

                deleteIfExists(
                    roiFolder +
                    pairBase +
                    ".tif"
                );

                deleteIfExists(
                    roiFolder +
                    pairBase +
                    ".png"
                );
            }
        }
    }
}

function deleteIfExists(path) {

    if (File.exists(path))
        File.delete(path);
}
