// ============================================================================
// STEP 1 — IMS FILE + CHANNEL IDENTIFICATION
// Version 3: interactive channel inspection BEFORE marker entry
//
// ONE FILE at a time.
//
// KEY DESIGN:
//   Normal Fiji Dialog windows are modal and prevent image interaction.
//   Therefore this macro uses waitForUser() during the inspection phase.
//   waitForUser() allows the student to interact with the image while the
//   instruction window remains open.
//
// WORKFLOW
//   1. Select ONE .ims file.
//   2. Open with Bio-Formats.
//   3. Detect C/Z/T.
//   4. INTERACTIVE INSPECTION:
//        - switch channels
//        - scroll Z
//        - zoom / pan
//        - adjust brightness & contrast for viewing
//      No pixel data are changed.
//   5. Click OK when inspection is complete.
//   6. Enter one biological marker label per detected channel.
//   7. Review + save channel map.
// ============================================================================

requires("1.53");

// ----------------------------------------------------------------------------
// 0. WELCOME
// ----------------------------------------------------------------------------
Dialog.create("Step 1 — Identify image channels");
Dialog.addMessage(
    "This step identifies the channels in ONE Imaris (.ims) image.\n\n" +
    "You will:\n" +
    "1. Choose the .ims image.\n" +
    "2. Inspect the image interactively in Fiji.\n" +
    "3. Switch through the detected channels and Z-planes.\n" +
    "4. Type the biological marker in each channel.\n" +
    "5. Review the channel map before it is saved.\n\n" +
    "No image processing will be performed."
);
Dialog.show();

// ----------------------------------------------------------------------------
// 1. SELECT ONE IMS FILE
// ----------------------------------------------------------------------------
inputPath = File.openDialog("Choose ONE Imaris (.ims) image");

if (inputPath == "")
    exit("No file was selected.\n\nNothing was changed.");

inputFileName = File.getName(inputPath);
inputFolder = File.getParent(inputPath) + File.separator;

lowerName = toLowerCase(inputFileName);

if (!endsWith(lowerName, ".ims"))
    exit(
        "Wrong file type selected.\n\n" +
        "This workflow expects an Imaris .ims file.\n\n" +
        "Selected file:\n" + inputFileName
    );

dotPosition = lastIndexOf(inputFileName, ".");
if (dotPosition > 0)
    sampleName = substring(inputFileName, 0, dotPosition);
else
    sampleName = inputFileName;

safeSampleName = makeSafeName(sampleName);

// ----------------------------------------------------------------------------
// 2. OPEN WITH STANDARD BIO-FORMATS IMPORTER
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
        "Please confirm the file opens normally using:\n" +
        "File > Import > Bio-Formats."
    );

importedTitle = getTitle();

getDimensions(sizeX, sizeY, sizeC, sizeZ, sizeT);

// ----------------------------------------------------------------------------
// 3. VALIDATE STRUCTURE
// ----------------------------------------------------------------------------
if (sizeC < 1) {
    close();
    exit(
        "Fiji did not detect any image channels.\n\n" +
        "Nothing was saved. Please ask the instructor to inspect this file."
    );
}

if (sizeC > 5) {
    detected = sizeC;
    close();
    exit(
        "This image contains " + detected + " channels.\n\n" +
        "This workflow currently supports 1–5 channels.\n\n" +
        "Nothing was saved."
    );
}

if (sizeT > 1) {
    detectedT = sizeT;
    close();
    exit(
        "TIME SERIES DETECTED\n\n" +
        "This file contains " + detectedT + " timepoints.\n\n" +
        "This version is intended for single-timepoint images.\n" +
        "Nothing was saved."
    );
}

// ----------------------------------------------------------------------------
// 4. PREPARE IMAGE FOR INTERACTIVE INSPECTION
// ----------------------------------------------------------------------------

// Make sure the imported image is active.
selectWindow(importedTitle);

// Composite display is useful for multichannel inspection.
if (sizeC > 1) {
    run("Make Composite");
}

// Open Brightness/Contrast as a modeless Fiji tool.
// This lets the student adjust DISPLAY ONLY while inspecting.
run("Brightness/Contrast...");

// Open Channels Tool for multichannel images.
// This gives a clear GUI for switching/showing channels.
if (sizeC > 1) {
    run("Channels Tool...");
}

// Start at first channel, first Z plane.
Stack.setPosition(1, 1, 1);

// ----------------------------------------------------------------------------
// 5. INTERACTIVE INSPECTION PHASE
//
// waitForUser() is intentional:
// Unlike Dialog.create(), it allows the user to keep interacting with Fiji.
// ----------------------------------------------------------------------------
inspectionText =
    "IMAGE INSPECTION\n\n" +
    "File: " + inputFileName + "\n\n" +
    "Detected:\n" +
    "  Channels: " + sizeC + "\n" +
    "  Z-planes: " + sizeZ + "\n" +
    "  Timepoints: " + sizeT + "\n\n" +
    "Before entering marker names, inspect the image.\n\n";

if (sizeC > 1) {
    inspectionText = inspectionText +
        "• Use the Channels Tool to show/hide individual channels.\n" +
        "• Move through Channel 1, Channel 2, etc.\n";
} else {
    inspectionText = inspectionText +
        "• This image has one detected channel.\n";
}

if (sizeZ > 1) {
    inspectionText = inspectionText +
        "• Scroll through the Z-stack using the image slider.\n";
}

inspectionText = inspectionText +
    "• You may zoom or pan.\n" +
    "• You may adjust Brightness/Contrast FOR VIEWING.\n" +
    "  These display adjustments do not alter the underlying pixel values.\n\n" +
    "Use your acquisition notes to determine what marker is in each channel.\n\n" +
    "When you are finished inspecting the image, click OK here.";

waitForUser(
    "Step 1 — Inspect channels",
    inspectionText
);

// ----------------------------------------------------------------------------
// 6. COLLECT MARKER NAMES
//
// Now that the student has finished looking, a normal modal dialog is fine.
// ----------------------------------------------------------------------------
Dialog.create("Step 1 — Label detected channels");

Dialog.addMessage(
    "Enter the BIOLOGICAL MARKER for each detected image channel.\n\n" +
    "Use the channel identity you just verified from the image and your\n" +
    "acquisition information.\n\n" +
    "Examples: DAPI, GFP, MAP2, NKX2.1, LHX6.\n\n" +
    "Do not assume marker identity based only on channel number."
);

for (c = 1; c <= sizeC; c++)
    Dialog.addString("Marker in Channel " + c + ":", "", 30);

Dialog.addCheckbox(
    "I checked these assignments against the image/acquisition information.",
    false
);

Dialog.show();

markers = newArray(sizeC);

for (c = 0; c < sizeC; c++)
    markers[c] = trimString(Dialog.getString());

confirmed = Dialog.getCheckbox();

if (!confirmed) {
    closeInspectionTools();
    selectWindow(importedTitle);
    close();

    exit(
        "The channel assignments were not confirmed.\n\n" +
        "Nothing was saved."
    );
}

// ----------------------------------------------------------------------------
// 7. VALIDATE MARKER NAMES
// ----------------------------------------------------------------------------
for (c = 0; c < sizeC; c++) {
    if (markers[c] == "") {
        missingChannel = c + 1;

        closeInspectionTools();
        selectWindow(importedTitle);
        close();

        exit(
            "Marker name is missing for Channel " + missingChannel + ".\n\n" +
            "Every detected channel needs a biological label.\n\n" +
            "Nothing was saved."
        );
    }
}

// Check duplicates
duplicateText = "";

for (i = 0; i < sizeC; i++) {
    for (j = i + 1; j < sizeC; j++) {
        if (toLowerCase(markers[i]) == toLowerCase(markers[j])) {
            duplicateText = duplicateText +
                "Channel " + (i + 1) + " and Channel " + (j + 1) +
                " are both labeled \"" + markers[i] + "\".\n";
        }
    }
}

if (duplicateText != "") {
    Dialog.create("Check duplicate marker names");
    Dialog.addMessage(
        "Duplicate marker names were entered:\n\n" +
        duplicateText + "\n" +
        "This may be correct, but please confirm."
    );
    Dialog.addCheckbox(
        "Yes — the duplicate marker names are intentional.",
        false
    );
    Dialog.show();

    keepDuplicates = Dialog.getCheckbox();

    if (!keepDuplicates) {
        closeInspectionTools();
        selectWindow(importedTitle);
        close();

        exit(
            "Nothing was saved.\n\n" +
            "Please run Step 1 again and correct the labels."
        );
    }
}

// ----------------------------------------------------------------------------
// 8. FINAL REVIEW
// ----------------------------------------------------------------------------
review = "";

for (c = 0; c < sizeC; c++) {
    review = review +
        "Channel " + (c + 1) + "  →  " + markers[c] + "\n";
}

Dialog.create("Review channel assignments");
Dialog.addMessage(
    "Please verify the channel map:\n\n" +
    review + "\n" +
    "These names will be used in downstream images and figures."
);
Dialog.addCheckbox("The channel map above is correct.", false);
Dialog.show();

finalApproved = Dialog.getCheckbox();

if (!finalApproved) {
    closeInspectionTools();
    selectWindow(importedTitle);
    close();

    exit(
        "Channel map was not approved.\n\n" +
        "Nothing was saved."
    );
}

// ----------------------------------------------------------------------------
// 9. CREATE OUTPUT FOLDER
// ----------------------------------------------------------------------------
analysisFolder =
    inputFolder +
    safeSampleName +
    "_FijiAnalysis" +
    File.separator;

stepFolder =
    analysisFolder +
    "00_import_and_channels" +
    File.separator;

File.makeDirectory(analysisFolder);
File.makeDirectory(stepFolder);

csvPath =
    stepFolder +
    safeSampleName +
    "_channel_map.csv";

txtPath =
    stepFolder +
    safeSampleName +
    "_import_summary.txt";

// ----------------------------------------------------------------------------
// 10. SAVE CSV
// ----------------------------------------------------------------------------
csv = "channel_index,user_marker\n";

for (c = 0; c < sizeC; c++) {
    csv = csv +
        (c + 1) + "," +
        csvQuote(markers[c]) + "\n";
}

File.saveString(csv, csvPath);

// ----------------------------------------------------------------------------
// 11. SAVE TXT SUMMARY
// ----------------------------------------------------------------------------
summary =
    "STEP 1 — IMS FILE + CHANNEL IDENTIFICATION\n" +
    "==========================================\n\n" +

    "SOURCE IMAGE\n" +
    "File name: " + inputFileName + "\n" +
    "Source path: " + inputPath + "\n" +
    "Imported Fiji title: " + importedTitle + "\n\n" +

    "DETECTED IMAGE STRUCTURE\n" +
    "Width: " + sizeX + " pixels\n" +
    "Height: " + sizeY + " pixels\n" +
    "Channels: " + sizeC + "\n" +
    "Z-planes: " + sizeZ + "\n" +
    "Timepoints: " + sizeT + "\n\n" +

    "CHANNEL MAP\n";

for (c = 0; c < sizeC; c++) {
    summary = summary +
        "Channel " + (c + 1) +
        " -> " + markers[c] + "\n";
}

summary = summary +
    "\nCONFIRMATION\n" +
    "Assignments checked against image/acquisition information: YES\n\n" +

    "PROCESSING STATUS\n" +
    "No pixel processing was performed in Step 1.\n" +
    "Brightness/contrast changes made during inspection were display-only.\n";

// Save
File.saveString(summary, txtPath);

// ----------------------------------------------------------------------------
// 12. CLEAN UP
// ----------------------------------------------------------------------------
closeInspectionTools();

selectWindow(importedTitle);
close();

// ----------------------------------------------------------------------------
// 13. SUCCESS
// ----------------------------------------------------------------------------
Dialog.create("Step 1 complete");
Dialog.addMessage(
    "Channel identification was saved successfully.\n\n" +
    review + "\n" +
    "Saved in:\n" +
    stepFolder + "\n\n" +
    "No pixel processing was performed."
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

function csvQuote(s) {
    s = replace(s, "\"", "\"\"");
    return "\"" + s + "\"";
}

function closeInspectionTools() {
    // These windows may or may not still be open.
    // Use window-title checks to avoid throwing an error.
    if (isOpen("B&C"))
        close("B&C");

    if (isOpen("Channels"))
        close("Channels");
}
