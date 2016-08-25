function plot_CCHF(sData, fieldsPlot, sMeta, path, varargin)
%If path is empty, wont write plot.  'Varargin' can be used to specify
%which points in sData to plot


%%SET PROPERTIES:
%Set font size:
ftSz = 14;
    ftSzT = ftSz + 2;
    ftSzAx = ftSz - 2;
%Set line width:
lnWd = 2;
    lnWdA = lnWd - 0.5;
strFont = 'Arial';
%Use these colors instead?
%From color Brewer):
clrBrewer = [228,26,28; ...
    55,126,184; ...
    77,175,74; ...
    152,78,163]/255;
custGray = [0.5,0.5,0.5];
%Nice colors for two tone comparisons:
clrCust = [0.1,0.6,0.1; 0.1,0.1,0.7]; %Custom green and purple
% szFrame = [3.5,3];
szFrame = [12,7];


%%RETRIEVE DATA FROM INPUT
flagDataExists = 0;
%Find all fields corresponding to each substructure in 'sData'
if ~isempty(fieldsPlot(:))
    if ischar(fieldsPlot)
       fieldsPlot = cellstr(fieldsPlot); 
    end
    
    fldsData = fieldnames(sData);
    
    %Varargin can be used to specify sub-structures to plot:
    if ~isempty(varargin)
        for ii = numel(fldsData) : -1 : 1
            if ~any(cellfun(@(x) strcmpi(fldsData{ii},x), varargin))
                fldsData(ii) = [];
            end
        end
    end
    
    
    indFieldsPlot = cell(numel(fieldsPlot),1);
    for ii = 1 : numel(fieldsPlot)
        cntrData = 0;
        for jj = 1 : numel(fldsData)
            %Find if any of the fields at the current point have data
            %If points with data exist, record index:
            if any(cellfun(@(x) strcmpi(fieldsPlot{ii},x), fieldnames(sData.(fldsData{jj}))))
                if any(sData.(char(fldsData{jj})).(fieldsPlot{ii}) ~= 0) && all(~isnan(sData.(char(fldsData{jj})).(fieldsPlot{ii})))
                    flagDataExists = 1;
                end
                cntrData = cntrData + 1;
                indFieldsPlot{ii}(cntrData) = jj;
            end
        end
    end
else
    warning('plot_SETI:noFields','No plot fields were provided.  Therefore the plot function is exiting.');
    return
end

if flagDataExists == 0
    warning('plot_SETI:noData','Plot_SETI is terminating without producing a plot because no data were found for the current field.');
    return
end



%%CREATE DATES FOR X-AXIS:
%Find number of time-series points:
for ii = 1 : numel(fieldsPlot)
    if ~isempty(indFieldsPlot{ii})
        nTsPts = numel(sData.(char(fldsData(indFieldsPlot{ii}(1)))).(fieldsPlot{ii}));
    end
end


if regexpbl(sMeta.dt, {'day','daily'})
    vecTsPts = (0:nTsPts-1);
elseif regexpbl(sMeta.dt, 'month')
    yearCurr = sMeta.dateStart(1);
    mnthCurr = sMeta.dateStart(2);
    
    vecTsPts = nan(nTsPts,1);
    vecTsPts(1) = 0;
    for ii = 2 : nTsPts
        mnthCurr = mnthCurr + 1;
        if mnthCurr == 13
            yearCurr = yearCurr + 1;
            mnthCurr = 1;
        end
        vecTsPts(ii) = vecTsPts(ii-1) + eomday(yearCurr,mnthCurr);
    end
else
    error('plot_SETI:timeStepUnknown',['The time step ' sMeta.dt ' has not been programmed for.']);
end





%%EXTRACT AND FORMAT DATA FOR PLOTTING:
dataPlot = cell(numel(indFieldsPlot),1);
[ dataPlot{:} ] = deal(nan(size(vecTsPts)));
for ii = numel(indFieldsPlot) : -1 : 1
    dataPlot{ii} = nan(nTsPts, numel(indFieldsPlot{ii}));
    for jj = numel(indFieldsPlot{ii}) : -1 : 1
        if all(isnan(sData.(char(fldsData(indFieldsPlot{ii}(jj)))).(fieldsPlot{ii})))
            indFieldsPlot{ii}(jj) = [];
            if jj > 1 && numel(dataPlot{ii}(1,:)) == jj
                dataPlot{ii} = dataPlot{ii}(:,1:jj-1);
            elseif jj > 1 && numel(dataPlot{ii}(1,:)) > jj
                dataPlot{ii} = [dataPlot{ii}(:,1:jj-1), dataPlot{ii}(:,jj+1:end)];
            elseif jj == 1 && numel(dataPlot{ii}(1,:)) == jj
                dataPlot{ii} = [];
            elseif jj == 1 && numel(dataPlot{ii}(1,:)) > jj
                dataPlot{ii} = dataPlot{ii}(:,jj+1:end);
            end
        else
            dataPlot{ii}(:,jj) = sData.(char(fldsData(indFieldsPlot{ii}(jj)))).(fieldsPlot{ii});
        end
    end
end



%%PLOT DATA
hFig = figure('Units','in','Position',[2 2 szFrame],'paperunits','in','paperposition',[2 2 szFrame]);
hTs = nan(1,1);
strSeries = cell(1,1);
yLab = blanks(0);


nSeries = 0;
for ii = 1 : numel(indFieldsPlot)
    nSeries = nSeries + numel(indFieldsPlot{ii});
end
          
%Set colors:
if nSeries == 1
    colorsUse = [0,0,0];
elseif nSeries == 2
    colorsUse = clrCust;
elseif nSeries <= 4
    colorsUse = clrBrewer;
else
    colorsUse = distinguishable_colors( nSeries );
end

hold on
indPlot = 0;
for ii = 1 : numel(indFieldsPlot)
    if ~isempty(indFieldsPlot{ii})
       for jj = 1 : numel(indFieldsPlot{ii})
            indPlot = indPlot + 1;

            hTs(indPlot) = plot((1:nTsPts), dataPlot{ii}(:,jj));

            %Set properties of current series:
            set(hTs(indPlot),'LineWidth',lnWd, ...
                'Color',colorsUse(mod(indPlot-1, nSeries)+1,:));

            coordCurr = [sData.(char(fldsData(indFieldsPlot{ii}(jj)))).('lon'), ...
                sData.(char(fldsData(indFieldsPlot{ii}(jj)))).('lat')];
            %Create legend entries:
            if any(~isnan(coordCurr))
                strSeries{indPlot} = [fieldsPlot{ii} ' (' num2str(coordCurr(1)), ', ' num2str(coordCurr(2)) ')'];
            else
                strSeries{indPlot} = [fieldsPlot{ii} ' (Domain Avg)'];
            end
       end

        %Create Y-axis Label:
        if ii == 1
            yLab = [yLab, char(fieldsPlot{ii})];
        else
            yLab = [yLab, ' / ', char(fieldsPlot{ii})];
        end  
    end
end
hold off

yLim = get(gca,'ylim');
if yLim(1) < 0 && yLim(2) > 0 
    hRef = line(get(gca,'xlim'),[0 0]);
    
    set(hRef,'LineWidth', lnWd, ...
        'LineStyle','--', ...
        'color',custGray);
end

%%CHANGE PLOT ATTRIBUTES:        
%Create legend:
hLgd = legend(hTs, strSeries);
%Change Axis Labels:
hXLab = xlabel('Date');
if regexpbl(sMeta.dt,{'day','daily'}) && numel(sMeta.dateStart) == 2
    sMeta.dateStart = [sMeta.dateStart 1];
end

strDates = date2str(days_2_date(vecTsPts, sMeta.dateStart, 'gregorian'), 'm/d/y');
nXTicks = round(linspace(1,nTsPts,10));
set(gca, 'XTickLabel',strDates(nXTicks), 'XTick',(nXTicks))
set(gca, 'XTickLabelRotation', 45);
%Guess data units:
if regexpbl(fieldsPlot{1}, 'stake')
    unitCurr = ' (Snow and Ice W.E.; m)';
elseif regexpbl(fieldsPlot{1}, 'snowradar')
    unitCurr = ' (SWE; m)';
elseif regexpbl(fieldsPlot{1}, 'flow')
    unitCurr = ' (m^3/s)';
elseif regexpbl(fieldsPlot{1}, 'heat')
    unitCurr = ' (W/m^2)';
else 
    unitCurr = ' (m)';
end


hYLab = ylabel([yLab ' ' unitCurr]);

%Set figure data properties:
set(hTs, ...
    'LineWidth', lnWd);
%Set axis and data frame properties:
set(hLgd, ...
    'FontSize'   , ftSz, ...
    'LineWidth', lnWdA,...
    'location','bestoutside');
%         set(hMnthELgd,'Layer','top');
set([hXLab, hYLab]  , ...
    'FontSize'   , ftSz, ...
    'Color', 'black', ...
    'FontName'   , strFont);
% set(hTtl, ...
%     'FontWeight' , 'bold', ...
%     'FontSize'   , ftSzT);

set(gca, ...
    'Box'         , 'off', ...
    'TickDir'     , 'out'     , ...
    'TickLength'  , [.02 .02] , ...
    'YMinorTick'  , 'on'      , ...
    'fontSize'    , ftSzAx, ...
    'LineWidth'   , lnWdA, ...
    'FontName'   , strFont);


%%WRITE FIGURE:
if ~isempty(path)
    [path, name, ~] = fileparts(path);

    if isempty(path) && ~isempty(name)
       path = fullfile(pwd, name); 
    elseif ~isempty(path) && ~isempty(name)
        path = fullfile(path, name);
    end 

    %set(gcf,'units','normalized','outerposition',[0 0 1 1]);
    savefig(hFig, [path '.fig']);
    print(hFig,    [path '.eps'],'-depsc2');
    print(hFig,    [path '.png'],'-dpng','-r600');
end
hold off