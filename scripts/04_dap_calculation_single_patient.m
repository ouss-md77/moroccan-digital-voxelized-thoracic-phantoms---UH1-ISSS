```matlab
clc;
clear;
close all;

%% ============================================================
% Anteroposterior Diameter Calculation
%
% Project: Moroccan Digital Voxelized Thoracic Phantoms
% Author: Oussama Aabi
%
% Description:
% This script calculates the anteroposterior diameter (DAP) from
% voxelized thoracic labelmaps.
%
% Method:
%   - Detect axial slices containing lungs
%   - Select 20 central lung slices
%   - Calculate the anteroposterior body diameter near the thoracic center
%   - Select the slice closest to the mean DAP for visualization
%
% Required Excel file:
%   data/spacing_patients.xlsx
%
% Expected local labelmap folders:
%   patient_H/labelmaps_H/
%   patient_F/labelmaps_F/
%   patient_E/labelmaps_E/
%
% Outputs:
%   - Excel file in results/tables/dap/
%   - PNG and FIG figures in results/figures/dap/
%
% Important:
% NRRD labelmaps are used locally and should not be uploaded to GitHub.
%% ============================================================

%% ===================== PROJECT FOLDER SELECTION =====================

projectFolder = uigetdir(pwd, 'Select the project folder');

if projectFolder == 0
    error('No project folder selected.');
end

excelFile = fullfile(projectFolder, 'data', 'spacing_patients.xlsx');

if ~isfile(excelFile)
    error('Excel file not found: %s', excelFile);
end

tablesFolder = fullfile(projectFolder, 'results', 'tables', 'dap');
figuresFolder = fullfile(projectFolder, 'results', 'figures', 'dap');

if ~exist(tablesFolder, 'dir')
    mkdir(tablesFolder);
end

if ~exist(figuresFolder, 'dir')
    mkdir(figuresFolder);
end

if exist('nrrdread', 'file') ~= 2
    error('The function nrrdread was not found. Please add an NRRD reader to the MATLAB path.');
end

%% ===================== PARAMETERS =====================

lungLabel = 1;
bodyLabel = 2;

numberOfCentralSlices = 20;
rotationK = 3;

minimumLungAreaVoxels = 100;

%% ===================== GROUP SELECTION =====================

fprintf('\n===== GROUP SELECTION =====\n');
fprintf('H : Male\n');
fprintf('F : Female\n');
fprintf('E : Child\n');

groupCode = upper(strtrim(input('Select the group (H/F/E): ', 's')));

if ~ismember(groupCode, {'H','F','E'})
    error('Invalid group. Please select only H, F, or E.');
end

switch groupCode
    case 'H'
        groupName = 'Male';
        sheetName = 'Homme';
        patientFolder = fullfile(projectFolder, 'patient_H');
        labelmapFolder = fullfile(patientFolder, 'labelmaps_H');

    case 'F'
        groupName = 'Female';
        sheetName = 'Femme';
        patientFolder = fullfile(projectFolder, 'patient_F');
        labelmapFolder = fullfile(patientFolder, 'labelmaps_F');

    case 'E'
        groupName = 'Child';
        sheetName = 'Enfant';
        patientFolder = fullfile(projectFolder, 'patient_E');
        labelmapFolder = fullfile(patientFolder, 'labelmaps_E');
end

if ~exist(labelmapFolder, 'dir')
    warning('Default labelmap folder not found: %s', labelmapFolder);

    selectedFolder = uigetdir(projectFolder, ['Select labelmap folder for group ', groupCode]);

    if selectedFolder == 0
        error('No labelmap folder selected.');
    end

    labelmapFolder = selectedFolder;
    patientFolder = fileparts(labelmapFolder);
end

%% ===================== PATIENT SELECTION =====================

patientInput = upper(strtrim(input(sprintf('Select the patient (%s1 to %s10): ', groupCode, groupCode), 's')));

if startsWith(patientInput, groupCode)
    patientName = patientInput;
else
    patientName = [groupCode patientInput];
end

validPatients = groupCode + string(1:10);

if ~ismember(patientName, validPatients)
    error('Invalid patient. Please select from %s1 to %s10.', groupCode, groupCode);
end

patientTablesFolder = fullfile(tablesFolder, patientName);
patientFiguresFolder = fullfile(figuresFolder, patientName);

if ~exist(patientTablesFolder, 'dir')
    mkdir(patientTablesFolder);
end

if ~exist(patientFiguresFolder, 'dir')
    mkdir(patientFiguresFolder);
end

%% ===================== READ EXCEL FILE =====================

try
    patientTable = readtable(excelFile, 'Sheet', sheetName, 'VariableNamingRule', 'preserve');
catch
    if strcmp(groupCode, 'F')
        sheetName = 'Femmes';
        patientTable = readtable(excelFile, 'Sheet', sheetName, 'VariableNamingRule', 'preserve');
    else
        error('Unable to read Excel sheet: %s', sheetName);
    end
end

patientColumn = getExistingColumn(patientTable, {'patient', 'id_patients', 'id_patient', 'Patient'});
spacingXColumn = getExistingColumn(patientTable, {'spacing_x', 'Spacing_X', 'Spacing_X_mm'});
spacingYColumn = getExistingColumn(patientTable, {'spacing_y', 'Spacing_Y', 'Spacing_Y_mm'});
spacingZColumn = getExistingColumn(patientTable, {'spacing_z', 'Spacing_Z', 'Spacing_Z_mm'});

patientIndex = strcmpi(string(patientTable.(patientColumn)), patientName);

if ~any(patientIndex)
    error('Patient %s not found in Excel sheet %s.', patientName, sheetName);
end

spacingX = patientTable.(spacingXColumn)(patientIndex);
spacingY = patientTable.(spacingYColumn)(patientIndex);
spacingZ = patientTable.(spacingZColumn)(patientIndex);

if ismember('file_nrrd', patientTable.Properties.VariableNames)
    labelmapFile = string(patientTable.file_nrrd(patientIndex));
elseif ismember('file_labelmap', patientTable.Properties.VariableNames)
    labelmapFile = string(patientTable.file_labelmap(patientIndex));
else
    labelmapFile = string([patientName '.nrrd']);
end

spacingXUsed = spacingY;
spacingYUsed = spacingX;

fprintf('\n===== Patient Information =====\n');
fprintf('Group: %s\n', groupName);
fprintf('Patient: %s\n', patientName);
fprintf('Excel sheet: %s\n', sheetName);
fprintf('Original spacing: %.6f x %.6f x %.6f mm\n', spacingX, spacingY, spacingZ);
fprintf('Spacing after rotation: X = %.6f mm | Y = %.6f mm\n', spacingXUsed, spacingYUsed);

%% ===================== FIND NRRD FILE =====================

nrrdPath = fullfile(labelmapFolder, labelmapFile);

if ~isfile(nrrdPath)
    nrrdPath = fullfile(labelmapFolder, [patientName '.nrrd']);
end

if ~isfile(nrrdPath)
    files = dir(fullfile(patientFolder, '**', [patientName '.nrrd']));
    if ~isempty(files)
        nrrdPath = fullfile(files(1).folder, files(1).name);
    else
        error('NRRD file not found for patient %s.', patientName);
    end
end

fprintf('NRRD file: %s\n', nrrdPath);

%% ===================== READ LABELMAP =====================

labelmap = nrrdread(nrrdPath);
labelmap = squeeze(labelmap);

lungMask = labelmap == lungLabel;
bodyMask = labelmap == bodyLabel;

if ~any(lungMask(:))
    error('Lung label %d was not found.', lungLabel);
end

if ~any(bodyMask(:))
    error('Body label %d was not found.', bodyLabel);
end

%% ===================== DETECT LUNG SLICES =====================

lungArea = squeeze(sum(sum(lungMask, 1), 2));
validSlices = find(lungArea > minimumLungAreaVoxels);

if isempty(validSlices)
    error('No slice containing lungs was found.');
end

%% ===================== SELECT CENTRAL SLICES =====================

if numel(validSlices) <= numberOfCentralSlices
    selectedSlices = validSlices;
else
    middleIndex = round(numel(validSlices) / 2);
    startIndex = middleIndex - floor(numberOfCentralSlices / 2);
    startIndex = max(1, startIndex);

    endIndex = startIndex + numberOfCentralSlices - 1;

    if endIndex > numel(validSlices)
        endIndex = numel(validSlices);
        startIndex = endIndex - numberOfCentralSlices + 1;
    end

    selectedSlices = validSlices(startIndex:endIndex);
end

fprintf('Number of lung slices: %d\n', numel(validSlices));
fprintf('Selected central slices: %d to %d\n', selectedSlices(1), selectedSlices(end));

%% ===================== DAP CALCULATION =====================

dapValuesMM = NaN(numel(selectedSlices), 1);
dapPoints = NaN(numel(selectedSlices), 4);

for i = 1:numel(selectedSlices)

    currentSlice = selectedSlices(i);

    body2D = rot90(bodyMask(:,:,currentSlice), rotationK);
    lung2D = rot90(lungMask(:,:,currentSlice), rotationK);

    fullBody = body2D | lung2D;

    if ~any(fullBody(:))
        continue;
    end

    [~, bodyColumns] = find(fullBody);
    xCenter = round(mean(bodyColumns));

    bandWidth = max(5, round(0.03 * size(fullBody, 2)));
    xBand = max(1, xCenter - bandWidth):min(size(fullBody, 2), xCenter + bandWidth);

    rowsBand = [];

    for x = xBand
        rows = find(fullBody(:, x));

        if ~isempty(rows)
            rowsBand = [rowsBand; rows(:)]; %#ok<AGROW>
        end
    end

    if isempty(rowsBand)
        continue;
    end

    anteriorY = min(rowsBand);
    posteriorY = max(rowsBand);
    xDAP = round(mean(xBand));

    dapValuesMM(i) = (posteriorY - anteriorY) * spacingYUsed;
    dapPoints(i,:) = [xDAP anteriorY xDAP posteriorY];
end

validDAP = ~isnan(dapValuesMM);

if ~any(validDAP)
    error('No valid DAP value was calculated for patient %s.', patientName);
end

meanDAPMM = mean(dapValuesMM, 'omitnan');
stdDAPMM = std(dapValuesMM, 'omitnan');

fprintf('\nDAP values for selected slices in mm:\n');
disp(dapValuesMM);

fprintf('Mean DAP = %.2f mm = %.2f cm\n', meanDAPMM, meanDAPMM / 10);
fprintf('DAP standard deviation = %.2f mm\n', stdDAPMM);

%% ===================== SLICE CLOSEST TO MEAN DAP =====================

distanceToMean = abs(dapValuesMM - meanDAPMM);
distanceToMean(~validDAP) = Inf;

[~, bestIndex] = min(distanceToMean);
bestSlice = selectedSlices(bestIndex);

fprintf('Slice closest to mean DAP: %d\n', bestSlice);

%% ===================== RESULT TABLE =====================

dapResults = table( ...
    repmat(string(patientName), numel(selectedSlices), 1), ...
    repmat(string(groupName), numel(selectedSlices), 1), ...
    selectedSlices(:), ...
    dapValuesMM, dapValuesMM / 10, ...
    repmat(meanDAPMM, numel(selectedSlices), 1), ...
    repmat(meanDAPMM / 10, numel(selectedSlices), 1), ...
    repmat(stdDAPMM, numel(selectedSlices), 1), ...
    'VariableNames', {'Patient','Group','Slice_Index','DAP_mm','DAP_cm', ...
    'Mean_DAP_Patient_mm','Mean_DAP_Patient_cm','DAP_Std_mm'});

summaryTable = table( ...
    string(patientName), string(groupName), string(groupCode), ...
    spacingX, spacingY, spacingZ, ...
    lungLabel, bodyLabel, ...
    validSlices(1), validSlices(end), ...
    selectedSlices(1), selectedSlices(end), ...
    numel(selectedSlices), ...
    bestSlice, ...
    meanDAPMM, meanDAPMM / 10, stdDAPMM, ...
    'VariableNames', {'Patient','Group','Group_Code', ...
    'Spacing_X_mm','Spacing_Y_mm','Spacing_Z_mm', ...
    'Lung_Label','Body_Label', ...
    'First_Lung_Slice','Last_Lung_Slice', ...
    'Selected_Start_Slice','Selected_End_Slice', ...
    'Number_Of_Selected_Slices', ...
    'Representative_Slice', ...
    'Mean_DAP_mm','Mean_DAP_cm','DAP_Std_mm'});

excelOutput = fullfile(patientTablesFolder, [patientName '_DAP_20_central_slices.xlsx']);

writetable(summaryTable, excelOutput, 'Sheet', 'Summary');
writetable(dapResults, excelOutput, 'Sheet', 'Slice_Details');

fprintf('Excel file saved: %s\n', excelOutput);

%% ===================== 2D DAP FIGURE =====================

body2D = rot90(bodyMask(:,:,bestSlice), rotationK);
lung2D = rot90(lungMask(:,:,bestSlice), rotationK);

imageRGB = zeros(size(body2D,1), size(body2D,2), 3);

imageRGB(:,:,2) = body2D * 0.8;
imageRGB(:,:,1) = imageRGB(:,:,1) + lung2D * 1.0;
imageRGB(:,:,2) = imageRGB(:,:,2) + lung2D * 1.0;

fig1 = figure('Color','w', 'Name','DAP representative slice');
imshow(imageRGB, []);
hold on;

xAnterior = dapPoints(bestIndex, 1);
yAnterior = dapPoints(bestIndex, 2);
xPosterior = dapPoints(bestIndex, 3);
yPosterior = dapPoints(bestIndex, 4);

bestDAPMM = dapValuesMM(bestIndex);
bestDAPCM = bestDAPMM / 10;

plot([xAnterior xPosterior], [yAnterior yPosterior], 'r-', 'LineWidth', 4);
plot(xAnterior, yAnterior, 'bo', 'MarkerSize', 8, 'LineWidth', 2);
plot(xPosterior, yPosterior, 'bo', 'MarkerSize', 8, 'LineWidth', 2);

text(xAnterior + 10, mean([yAnterior yPosterior]), ...
    sprintf('DAP = %.1f mm = %.2f cm', bestDAPMM, bestDAPCM), ...
    'Color','w', ...
    'FontSize',12, ...
    'FontWeight','bold', ...
    'BackgroundColor','black');

title(sprintf('%s - DAP | Slice %d | Mean DAP = %.2f mm = %.2f cm', ...
    patientName, bestSlice, meanDAPMM, meanDAPMM / 10));

saveas(fig1, fullfile(patientFiguresFolder, [patientName '_DAP_2D_representative_slice.png']));
savefig(fig1, fullfile(patientFiguresFolder, [patientName '_DAP_2D_representative_slice.fig']));

%% ===================== DAP CURVE =====================

fig2 = figure('Color','w', 'Name','DAP variation across selected slices');
plot(selectedSlices, dapValuesMM, '-o', 'LineWidth', 2);
hold on;
yline(meanDAPMM, '--', sprintf('Mean DAP = %.2f mm = %.2f cm', meanDAPMM, meanDAPMM / 10), 'LineWidth', 2);
plot(bestSlice, bestDAPMM, 'ro', 'MarkerSize', 10, 'LineWidth', 2);
hold off;

grid on;
box on;

xlabel('Slice index');
ylabel('DAP (mm)');
title(sprintf('DAP Variation Across 20 Central Slices - %s', patientName));

saveas(fig2, fullfile(patientFiguresFolder, [patientName '_DAP_variation_20_central_slices.png']));
savefig(fig2, fullfile(patientFiguresFolder, [patientName '_DAP_variation_20_central_slices.fig']));

fprintf('\n===== Processing completed successfully for %s =====\n', patientName);
fprintf('Tables saved in:\n%s\n', patientTablesFolder);
fprintf('Figures saved in:\n%s\n', patientFiguresFolder);

%% ============================================================
% LOCAL FUNCTIONS
%% ============================================================

function columnName = getExistingColumn(inputTable, possibleNames)

    columnName = "";

    for i = 1:numel(possibleNames)
        if ismember(possibleNames{i}, inputTable.Properties.VariableNames)
            columnName = possibleNames{i};
            return;
        end
    end

    error('None of the required columns was found: %s', strjoin(possibleNames, ', '));
end
```
