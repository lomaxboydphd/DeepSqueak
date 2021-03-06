function SyntaxAnalysis_Callback(hObject, eventdata, handles)

[filename filepath] = uigetfile({'*.mat;*.xlsx'},'Select Detection Files OR Exported Detections','MultiSelect', 'on',char(handles.settings.detectionfolder));
if isnumeric(filename); return; end

if ischar(filename)
    tmp{1}=filename;
    clear trainingdata
    filename=tmp;
end

settings = inputdlg({'Maximum bout seperation (s)','Exclude Classes with frequency below (0-1)'},'Syntax',[1 50],{'10','.01'});
boutlength = str2num(settings{1});
minfreq = str2num(settings{2});

[~,~,ext] = fileparts(filename{1});

h = waitbar(0,'Loading Files');
%% Load Files
if strcmp(ext,'.mat')
    AllCalls = table([],[],[],[],[],'VariableNames',{'BeginTime_s_','Label','File','Bout','Accepted'});
    for i = 1:length(filename)
        load([filepath filename{i}],'Calls');
        Calls = Calls([Calls.Accept]' == 1);
        begintime = [Calls.Box]'; % Get Box Position
        begintime = begintime(1:4:end); % Every forth element is the begin time
        CallClass = [Calls.Type]';
        dist = pdist2(begintime,begintime);
        dist(dist > boutlength) = 0;
        G = graph(dist);
        bout = conncomp(G)';
        
        g = table(begintime, CallClass, repmat(i,length(Calls),1), bout,[Calls.Accept]','VariableNames',{'BeginTime_s_','Label','File','Bout','Accepted'});
        AllCalls = [AllCalls; g];
        waitbar(i/length(filename),h)
        
    end
else
    for i = 1:length(filename)
        t = readtable([filepath filename{i}]);
        t = t(t.Accepted == 1,{'Accepted' 'BeginTime_s_','Label'});
        dist = pdist2(t.BeginTime_s_,t.BeginTime_s_);
        dist(dist > boutlength) = 0;
        G = graph(dist);
        bout = conncomp(G)';
        g = table(bout,repmat(i,height(t),1),'VariableNames',{'Bout','File'});
        AllCalls = [AllCalls; g t];
        waitbar(i/length(filename),h)
        
    end
end
AllCalls = sortrows(AllCalls,{'File' 'BeginTime_s_'});

%% Exclude rare classes and rejected calls
catcounts = countcats(AllCalls.Label);
CommonClasses = (catcounts ./ sum(catcounts)) > minfreq;
cats = categories(AllCalls.Label);
goodCalls = any(AllCalls.Label == cats(CommonClasses)',2);
AllCalls = AllCalls(AllCalls.Accepted == 1 & goodCalls ,:);
AllCalls.Label = removecats(AllCalls.Label);
cats = categories(AllCalls.Label);

%% Create Transition Table
counts = [];
for i = 1:length(cats)
    for j = 1:length(cats)
        %         counts(j,i) = mean((AllCalls{1:end-1,'Label'} == cats{i}) & (AllCalls{2:end,'Label'} == cats{j}));
        x = sum(...
            ((AllCalls{1:end-1,'Label'} == cats{i}) & (AllCalls{2:end,'Label'} == cats{j})) & ...
            (AllCalls{1:end-1,'Bout'} == AllCalls{2:end,'Bout'}) &...
            (AllCalls{1:end-1,'File'} == AllCalls{2:end,'File'}));
        n = sum(AllCalls{2:end,'Label'} == cats{j});
        counts(j,i) = x / n;
    end
end
delete(h)


%% Create Figures
figure('position',[0 0 700 600],'color','w')
h = heatmap(cats,cats,counts,'ColorMethod','mean');
h.Colormap = plasma;
h.XLabel = 'Transition Probability';
h.YLabel = 'Syllable';
set(gcf,'Colormap',plasma);
set(gca,'GridVisible','off','FontSize',14);
h.CellLabelFormat = '%.3f';
colorbar off

figure('position',[300 0 700 600],'color','w')
counts(counts<.05)=0;
G = digraph(counts,cats);
g = plot(G,'EdgeCData',G.Edges.Weight);
axis off
g.ArrowSize = 10;
g.LineWidth = 10*G.Edges.Weight;
g.EdgeAlpha = .8;
layout(g,'layered');
set(gcf,'Colormap',plasma);


%% Save Matrix
[file,path] = uiputfile('*.xlsx','Save Transion Matrix');

if ~isnumeric(file)
output = [];
counts = cell(length(cats));
for i = 1:length(cats)
    for j = 1:length(cats)
        %         counts(j,i) = mean((AllCalls{1:end-1,'Label'} == cats{i}) & (AllCalls{2:end,'Label'} == cats{j}));
        x = sum(...
            ((AllCalls{1:end-1,'Label'} == cats{i}) & (AllCalls{2:end,'Label'} == cats{j})) & ...
            (AllCalls{1:end-1,'Bout'} == AllCalls{2:end,'Bout'}) &...
            (AllCalls{1:end-1,'File'} == AllCalls{2:end,'File'}));
        n = sum(AllCalls{2:end,'Label'} == cats{j});
        counts(j,i) = {x / n};
    end
end
output = [output; [{'Conditional Probability'} cell(1,length(cats))]];
output = [output; [[{'Category'} cats'] ; [cats, counts]]];

counts = cell(length(cats));
for i = 1:length(cats)
    for j = 1:length(cats)
        %         counts(j,i) = mean((AllCalls{1:end-1,'Label'} == cats{i}) & (AllCalls{2:end,'Label'} == cats{j}));
        x = sum(...
            ((AllCalls{1:end-1,'Label'} == cats{i}) & (AllCalls{2:end,'Label'} == cats{j})) & ...
            (AllCalls{1:end-1,'Bout'} == AllCalls{2:end,'Bout'}) &...
            (AllCalls{1:end-1,'File'} == AllCalls{2:end,'File'}));
        counts(j,i) = {x };
    end
end
output = [output; cell(3,length(cats)+1)];
output = [output; [{'Transition Count'} cell(1,length(cats))]];
output = [output;[[{'Category'} cats'] ; [cats, counts]]];


counts = cell(length(cats),1);
for i = 1:length(cats)
        counts(i) = {sum(AllCalls{1:end,'Label'} == cats{i})};
end

output = [output; cell(3,length(cats)+1)];
output = [output; [{'Total Count'} cell(1,length(cats))]];
output = [output; cats, counts, cell(length(cats),length(cats)-1)];


writetable(cell2table(output),[path file],'WriteVariableNames',0);
end


end






















