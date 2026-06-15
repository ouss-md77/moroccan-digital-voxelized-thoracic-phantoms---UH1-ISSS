```matlab
clc;
clear;
close all;

%% ============================================================
% 2D and 3D Visualization of Voxelized Lung Labelmaps
%
% Project: Moroccan Digital Voxelized Thoracic Phantoms
% Author: Oussama Aabi
%
% Description:
% This script displays a voxelized lung labelmap in:
%   - XZ plane
%   - XY plane
%   - 3D XYZ view
%
% The script reads a NRRD or NHDR labelmap, extracts voxel spacing from
% the header when available, calculates the lung volume, and saves figures.
%
% Outputs:
%   - PNG and FIG figures in results/figures/visualization/
%   - Excel summary in results/tables/visualization/
%
% Important:
% NRRD labelmaps are used locally and should not be uploaded to GitHub.
%% ============================================================

%% ===================== PROJECT FOLDER SELECTION =====================

projectFolder = uigetdir(pwd, 'Select the project folder');

if projectFolder == 0
    error('No project folder selected.');
end

figuresFolder = fullfile(projectFolder, 'results', 'figures', 'visualization');
tablesFolder = fullfile(projectFolder, 'results', 'tables', 'visualization');

if ~exist(figuresFolder, 'dir')
    mkdir(figuresFolder);
end

if ~exist(tablesFolder, 'dir')
    mkdir(tablesFolder);
end

%% ===================== SELECT NRRD LABELMAP =====================

[fileName, filePath] = uigetfile( ...
    {'*.nrrd;*.nhdr', 'NRRD files (*.nrrd, *.nhdr)'}, ...
    'Select the lung labelmap file', ...
    projectFolder);

if isequal(fileName, 0)
    error('No NRRD file selected.');
end

nrrdFile = fullfile(filePath, fileName);

fprintf('\nSelected file:\n%s\n', nrrdFile);

[~, baseName, ~] = fileparts(fileName);

%% ===================== READ NRRD FILE =====================

[labelmap, metadata] = readNrrdFile(nrrdFile);

labelmap = squeeze(labelmap);
labelmap = double(labelmap);

if ndims(labelmap) ~= 3
    error('The selected labelmap must be a 3D volume.');
end

%% ===================== VOXEL SPACING =====================

spacing = extractNrrdSpacing(metadata);

if any(isnan(spacing)) || numel(spacing) < 3

    prompt = {'Spacing X (mm):', 'Spacing Y (mm):', 'Spacing Z (mm):'};
    dialogTitle = 'Voxel spacing';
    defaultValues = {'1', '1', '1'};

    answer = inputdlg(prompt, dialogTitle, [1 50], defaultValues);

    if isempty(answer)
        error('No spacing values were entered.');
    end

    spacingX = str2double(answer{1});
    spacingY = str2double(answer{2});
    spacingZ = str2double(answer{3});

else
    spacingX = spacing(1);
    spacingY = spacing(2);
    spacingZ = spacing(3);
end

if any(isnan([spacingX spacingY spacingZ])) || any([spacingX spacingY spacingZ] <= 0)
    error('Invalid voxel spacing values.');
end

fprintf('Voxel spacing: %.6f x %.6f x %.6f mm\n', spacingX, spacingY, spacingZ);

%% ===================== LABEL SELECTION =====================

availableLabels = unique(labelmap(:));
availableLabels = availableLabels(availableLabels > 0);

if isempty(availableLabels)
    error('No non-zero label was found in the selected labelmap.');
end

fprintf('\nDetected labels:\n');
disp(availableLabels(:)');

prompt = {'Enter lung label value, or write "all" to use all non-zero labels:'};
dialogTitle = 'Lung label selection';
defaultValue = {'1'};

answer = inputdlg(prompt, dialogTitle, [1 70], defaultValue);

if isempty(answer)
    error('No label value entered.');
end

labelAnswer = strtrim(answer{1});

if strcmpi(labelAnswer, 'all')
    lungMask = labelmap > 0;
    selectedLabelText = "All non-zero labels";
else
    lungLabel = str2double(labelAnswer);

    if isnan(lungLabel)
        error('Invalid label value.');
    end

    lungMask = labelmap == lungLabel;
    selectedLabelText = string(lungLabel);
end

numberOfVoxels = nnz(lungMask);

if numberOfVoxels == 0
    error('The selected lung mask is empty. Please check the label value.');
end

%% ===================== VOLUME CALCULATION =====================

voxelVolume_mm3 = spacingX * spacingY * spacingZ;
volume_mm3 = numberOfVoxels * voxelVolume_mm3;
volume_cm3 = volume_mm3 / 1000;
volume_L = volume_cm3 / 1000;

fprintf('\n====================================\n');
fprintf('Number of lung voxels = %d\n', numberOfVoxels);
fprintf('Lung volume = %.2f mm3\n', volume_mm3);
fprintf('Lung volume = %.2f cm3\n', volume_cm3);
fprintf('Lung volume = %.3f L\n', volume_L);
fprintf('====================================\n');

%% ===================== DIMENSIONS =====================

[numberX, numberY, numberZ] = size(lungMask);

xAxis = (0:numberX-1) * spacingX;
yAxis = (0:numberY-1) * spacingY;
zAxis = (0:numberZ-1) * spacingZ;

middleY = round(numberY / 2);
middleZ = round(numberZ / 2);

%% ===================== 2D AND 3D FIGURE =====================

figMain = figure('Color', 'w', 'Name', 'Voxelized lungs - 2D and 3D views');

tiledlayout(1, 3, 'TileSpacing', 'compact', 'Padding', 'compact');

%% XZ plane
nexttile;

imageXZ = squeeze(lungMask(:, middleY, :));

imagesc(xAxis, zAxis, imageXZ');
axis image;
set(gca, 'YDir', 'normal');

xlabel('X (mm)');
ylabel('Z (mm)');
title('XZ plane');
grid on;
box on;

%% XY plane
nexttile;

imageXY = squeeze(lungMask(:, :, middleZ));

imagesc(xAxis, yAxis, imageXY');
axis image;
set(gca, 'YDir', 'normal');

xlabel('X (mm)');
ylabel('Y (mm)');
title('XY plane');
grid on;
box on;

%% 3D view
nexttile;

surfaceData = smooth3(single(lungMask), 'box', 3);
surfaceModel = isosurface(surfaceData, 0.5);

surfaceModel.vertices(:,1) = surfaceModel.vertices(:,1) * spacingX;
surfaceModel.vertices(:,2) = surfaceModel.vertices(:,2) * spacingY;
surfaceModel.vertices(:,3) = surfaceModel.vertices(:,3) * spacingZ;

patch(surfaceModel, ...
    'FaceColor', [0.2 0.8 1], ...
    'EdgeColor', 'none', ...
    'FaceAlpha', 0.85);

axis equal;
grid on;
box on;

xlabel('X (mm)');
ylabel('Y (mm)');
zlabel('Z (mm)');
title('3D XYZ view');

view(3);
camlight;
lighting gouraud;
rotate3d on;

sgtitle(['Voxelized Lung Visualization - ', baseName], 'Interpreter', 'none');

mainFigurePNG = fullfile(figuresFolder, [baseName '_2D_3D_lung_visualization.png']);
mainFigureFIG = fullfile(figuresFolder, [baseName '_2D_3D_lung_visualization.fig']);

saveas(figMain, mainFigurePNG);
savefig(figMain, mainFigureFIG);

%% ===================== 3D FIGURE ONLY =====================

fig3D = figure('Color', 'w', 'Name', '3D voxelized lungs');

patch(surfaceModel, ...
    'FaceColor', [0.2 0.8 1], ...
    'EdgeColor', 'none', ...
    'FaceAlpha', 0.85);

axis equal;
grid on;
box on;

xlabel('X (mm)');
ylabel('Y (mm)');
zlabel('Z (mm)');
title(['3D Visualization of Voxelized Lungs - ', baseName], 'Interpreter', 'none');

view(3);
camlight;
lighting gouraud;
rotate3d on;

figure3DPNG = fullfile(figuresFolder, [baseName '_3D_lungs_XYZ.png']);
figure3DFIG = fullfile(figuresFolder, [baseName '_3D_lungs_XYZ.fig']);

saveas(fig3D, figure3DPNG);
savefig(fig3D, figure3DFIG);

%% ===================== SAVE SUMMARY TABLE =====================

summaryTable = table( ...
    string(baseName), string(fileName), string(selectedLabelText), ...
    spacingX, spacingY, spacingZ, voxelVolume_mm3, ...
    numberX, numberY, numberZ, ...
    numberOfVoxels, volume_mm3, volume_cm3, volume_L, ...
    'VariableNames', {'Patient_or_File_ID','File_NRRD','Selected_Label', ...
    'Spacing_X_mm','Spacing_Y_mm','Spacing_Z_mm','Voxel_Volume_mm3', ...
    'Size_X','Size_Y','Size_Z', ...
    'Number_Of_Voxels','Volume_mm3','Volume_cm3','Volume_L'});

summaryExcel = fullfile(tablesFolder, [baseName '_lung_visualization_summary.xlsx']);
writetable(summaryTable, summaryExcel, 'Sheet', 'Summary');

fprintf('\n===== Processing completed successfully =====\n');
fprintf('Summary table saved in:\n%s\n', summaryExcel);
fprintf('Figures saved in:\n%s\n', figuresFolder);

%% ============================================================
% LOCAL FUNCTIONS
%% ============================================================

function [data, metadata] = readNrrdFile(filePath)

    if exist('nrrdread', 'file') == 2
        data = nrrdread(filePath);
        metadata = readNrrdHeader(filePath);
    else
        [data, metadata] = nrrdreadCustom(filePath);
    end
end

function metadata = readNrrdHeader(filePath)

    fid = fopen(filePath, 'rb');

    if fid < 0
        error('Unable to open NRRD file.');
    end

    metadata = struct();
    firstLine = fgetl(fid);

    if ~contains(firstLine, 'NRRD')
        fclose(fid);
        error('The selected file is not a valid NRRD file.');
    end

    while true
        line = fgetl(fid);

        if ~ischar(line)
            break;
        end

        if isempty(strtrim(line))
            break;
        end

        if startsWith(line, '#')
            continue;
        end

        tokens = regexp(line, '([^:]+):\s*(.*)', 'tokens');

        if isempty(tokens)
            continue;
        end

        key = strtrim(tokens{1}{1});
        value = strtrim(tokens{1}{2});

        keyClean = matlab.lang.makeValidName(key);
        metadata.(keyClean) = value;
    end

    fclose(fid);
end

function spacing = extractNrrdSpacing(metadata)

    spacing = [NaN NaN NaN];

    if isfield(metadata, 'space_directions')
        value = metadata.space_directions;
    elseif isfield(metadata, 'spaceDirections')
        value = metadata.spaceDirections;
    else
        value = "";
    end

    if strlength(string(value)) > 0

        parts = regexp(value, '\([^\)]*\)|none', 'match');
        directions = [];

        for i = 1:numel(parts)

            currentPart = strtrim(parts{i});

            if strcmpi(currentPart, 'none')
                continue;
            end

            numbers = regexp(currentPart, '[-+]?\d*\.?\d+(?:[eE][-+]?\d+)?', 'match');
            numbers = str2double(numbers);

            if ~isempty(numbers)
                directions(end + 1) = norm(numbers); %#ok<AGROW>
            end
        end

        if numel(directions) >= 3
            spacing = directions(1:3);
            return;
        end
    end

    if isfield(metadata, 'spacings')
        numbers = regexp(metadata.spacings, '[-+]?\d*\.?\d+(?:[eE][-+]?\d+)?', 'match');
        numbers = str2double(numbers);

        if numel(numbers) >= 3
            spacing = numbers(1:3);
        end
    end
end

function [data, metadata] = nrrdreadCustom(filePath)

    fid = fopen(filePath, 'rb');

    if fid < 0
        error('Unable to open NRRD file.');
    end

    metadata = struct();
    firstLine = fgetl(fid);

    if ~contains(firstLine, 'NRRD')
        fclose(fid);
        error('The selected file is not a valid NRRD file.');
    end

    while true
        line = fgetl(fid);

        if ~ischar(line)
            break;
        end

        if isempty(strtrim(line))
            break;
        end

        if startsWith(line, '#')
            continue;
        end

        tokens = regexp(line, '([^:]+):\s*(.*)', 'tokens');

        if isempty(tokens)
            continue;
        end

        key = strtrim(tokens{1}{1});
        value = strtrim(tokens{1}{2});

        keyClean = matlab.lang.makeValidName(key);
        metadata.(keyClean) = value;
    end

    if ~isfield(metadata, 'sizes')
        fclose(fid);
        error('NRRD header is missing the sizes field.');
    end

    sizes = sscanf(metadata.sizes, '%d')';

    if ~isfield(metadata, 'type')
        fclose(fid);
        error('NRRD header is missing the type field.');
    end

    type = lower(metadata.type);

    if isfield(metadata, 'encoding')
        encoding = lower(metadata.encoding);
    else
        encoding = 'raw';
    end

    switch type
        case {'uchar', 'unsigned char', 'uint8'}
            matlabType = 'uint8';
        case {'signed char', 'int8'}
            matlabType = 'int8';
        case {'short', 'short int', 'signed short', 'int16'}
            matlabType = 'int16';
        case {'ushort', 'unsigned short', 'uint16'}
            matlabType = 'uint16';
        case {'int', 'signed int', 'int32'}
            matlabType = 'int32';
        case {'uint', 'unsigned int', 'uint32'}
            matlabType = 'uint32';
        case {'float'}
            matlabType = 'single';
        case {'double'}
            matlabType = 'double';
        otherwise
            fclose(fid);
            error('Unsupported NRRD data type: %s', type);
    end

    switch encoding
        case {'raw'}
            data = fread(fid, prod(sizes), ['*' matlabType]);

        case {'ascii', 'text', 'txt'}
            data = fscanf(fid, '%f');
            data = cast(data, matlabType);

        otherwise
            fclose(fid);
            error('Unsupported NRRD encoding: %s. Please export the NRRD file using raw encoding.', encoding);
    end

    fclose(fid);

    if numel(data) ~= prod(sizes)
        error('The data size does not match the NRRD header sizes.');
    end

    data = reshape(data, sizes);
end
```
