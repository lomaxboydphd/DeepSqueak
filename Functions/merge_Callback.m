function merge_Callback(hObject, eventdata, handles)

cd(handles.squeakfolder);
[trainingdata trainingpath] = uigetfile([handles.settings.detectionfolder '/*.mat'],'Select Detection File(s) for Merging','MultiSelect', 'on');
[audiodata audiopath] = uigetfile({'*.wav;*.flac;*.UVD' 'Audio File';'*.wav' 'WAV(*.wav)'; '*.flac' 'FLAC (*.flac)'; '*.UVD' 'Ultravox File (*.UVD)'},'Select Corresponding Audio File',handles.settings.detectionfolder);
hc = waitbar(0,'Merging Output Structures');  

cd(handles.squeakfolder);
if ischar(trainingdata)==1
   tmp{1}=trainingdata;
   clear trainingdata
   trainingdata=tmp;
end

for j = 1:length(trainingdata)
load([trainingpath trainingdata{j}]);
if j==1
A = Calls';
else   
B=Calls';
A=[A;B];
end
end
clear('Calls')
% Audio info
info = audioinfo([audiopath audiodata]);

%% Merge overlapping boxes
for i=1:length(A)
AllBoxes(i,1:4)=A(i).Box;
AllScores(i,1)=A(i).Score;
AllRelBoxes(i,1:4)=A(i).RelBox;
AllPower(i,1)=A(i).Power;
AllAccept(i,1)=A(i).Accept;
end
xmin = AllBoxes(:,1);
ymin = AllBoxes(:,2);
xmax = xmin + AllBoxes(:,3) - 1;
ymax = ymin + AllBoxes(:,4) - 1;

overlapRatio = bboxOverlapRatio(AllBoxes, AllBoxes);
n = size(overlapRatio,1);
overlapRatio(1:n+1:n^2) = 0;
g = graph(overlapRatio);
componentIndices = conncomp(g);

xmin = accumarray(componentIndices', xmin, [], @min);
ymin = accumarray(componentIndices', ymin, [], @min);
xmax = accumarray(componentIndices', xmax, [], @max);
ymax = accumarray(componentIndices', ymax, [], @max);

[z1 z2 z3]=unique(componentIndices);
merged_boxes = [xmin ymin xmax-xmin+1 ymax-ymin+1];
merged_scores = accumarray(componentIndices', AllScores, [], @max);
merged_power = accumarray(componentIndices', AllPower, [], @max);
merged_accept = accumarray(componentIndices', AllAccept, [], @max);

% Re Make Call Structure
for i=1:length(merged_boxes)
waitbar(i/length(merged_boxes),hc); 

WindL=round((merged_boxes(i,1)-(merged_boxes(i,3)))*(info.SampleRate));
if WindL<=1
    pad=abs(WindL);
    WindL = 1;
end
WindR=round((merged_boxes(i,1)+merged_boxes(i,3)+(merged_boxes(i,3)))*(info.SampleRate));
a = audioread([audiopath audiodata],[WindL WindR],'native');
if WindL==1;
   pad=zeros(pad,1);
   a=[pad 
       a];
end

% Final Structure
Calls(i).Rate=info.SampleRate;
Calls(i).Box=merged_boxes(i,:);
Calls(i).RelBox=[merged_boxes(i,3) merged_boxes(i,2) merged_boxes(i,3) merged_boxes(i,4)];
Calls(i).Score=merged_scores(i);
Calls(i).Audio=a;
Calls(i).Type=categorical({'USV'});
Calls(i).Power=merged_power(i);
Calls(i).Accept=merged_accept(i);
end


[FileName,PathName,FilterIndex] = uiputfile([handles.settings.detectionfolder '/*.mat'],'Save Merged Detections');
waitbar(i/length(merged_boxes),hc,'Saving...'); 
save([PathName,FileName],'Calls','-v7.3');
update_folders(hObject, eventdata, handles);
handles = guidata(hObject);  % Get newest version of handles
close(hc);

