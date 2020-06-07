% Copyright 2013, 2014, 2015, 2016 Thomas M. Mosier, Kendra V. Sharp, and 
% David F. Hill
% This file is part of multiple packages, including the GlobalClimateData 
% Downscaling Package, the Hydropower Potential Assessment Tool, and the 
% Conceptual Cryosphere Hydrology Framework.
% 
% The above named packages are free software: you can 
% redistribute it and/or modify it under the terms of the GNU General 
% Public License as published by the Free Software Foundation, either 
% version 3 of the License, or (at your option) any later version.
% 
% The above named packages are distributed in the hope that it will be 
% useful, but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General
% Public License for more details.
% 
% You should have received a copy of the GNU General Public License
% along with the Downscaling Package.  If not, see 
% <http://www.gnu.org/licenses/>.

function varargout = print_model_state_v4(sHydro, sMeta, pathOut)

%Use global and persistent variles.
%Persistent variable 'sModOut' speeds run time by close to factor of 100
global sAtm sCryo sLand sModOut



varLat = 'latitude';
varLon = 'longitude';

%Mass balance fields are treated differently than other cryosphere fields because they are only recorded once every year.
fldsmb = {'igrdmb'; 'icmb'}; 
varGeodetic = 'geodetic';
varStake = 'stake';
varCasi = 'casi';
%Remove mass balance fields from cryosphere
fldsCryoAll = fieldnames(sCryo);
fldsCryo = setdiff([fldsCryoAll; varCasi; varStake; varGeodetic], fldsmb);
fldsAtm  = fieldnames(sAtm);
fldsLand = fieldnames(sLand);

szMain = size(sHydro.dem);

%Determine if ice grid different from main grid:
if isfield(sCryo,'iceDem') && ~isequal(szMain,size(sCryo.iceDem))
    iceGrid = 1;
else
    iceGrid = 0;
end



%Don't write during spinup, only write if output requested, and if
%model not bieng run in parameter retrieve mode
if sMeta.indCurr < sMeta.indWrite
    return
else
    indTsPrintCurr = sMeta.indCurr - sMeta.indWrite + 1;
    
    sMeta.foldWrtData = fullfile(pathOut, 'model_output_grids');
        
    %Indices in 2d model domain:
    indNan2d = find(isnan(sHydro.dem));
    indNNan2d = find(~isnan(sHydro.dem));
    
    %On first iteration, create output structure array:
    if indTsPrintCurr == 1 || isempty(sModOut)
        sModOut = struct;
        
        %Set current run dates (used for initialization
        datesUse = sMeta.dateRun;
        if iscell(datesUse)
            if isfield(sMeta, 'siteCurr')
                datesUse = datesUse{sMeta.siteCurr};
                dateStart = sMeta.dateStart{sMeta.siteCurr};
                dateEnd = sMeta.dateEnd{sMeta.siteCurr};
            else
                error('CchfModules:noSiteCurr', ['The date field is a cellarray. '...
                    'This requires the presence of a siteCurr field to determine which index to use.']);
            end
        end
        
        outDate = date_vec_fill(dateStart, dateEnd, 'Gregorian');
        szInitPt = [numel(outDate(:,1)),1];
        szInit3d = [numel(outDate(:,1)),numel(sHydro.(varLat)),numel(sHydro.(varLon))];
        
        %If ice grid different, but define variables to place output within
        %ice grid:
        if iceGrid == 1
            edgLat = box_edg(sCryo.iceLat);
            edgLon = box_edg(sCryo.iceLon);
            szIce = size(sCryo.iceDem);
        end

        %Loop over all variables to output
        for kk = 1 : numel(sMeta.output{sMeta.siteCurr}(:,1)) 
            varCurr = sMeta.output{sMeta.siteCurr}{kk,1};
            if iscell(varCurr)
                varCurr = varCurr{:};
            end
            
            %loop over points where model output should be written:
            for ll = 1 : numel(sMeta.output{sMeta.siteCurr}{kk,3}(:)) 
                ptCurr = sMeta.output{sMeta.siteCurr}{kk,3}{ll};
                
                %Switch between types of output points ('avg', 'all', or
                %specific point)
                if strcmpi(ptCurr,'avg')
                    if ~isfield(sModOut,'avg') || isempty(sModOut.avg)
                        sModOut.avg = struct;
                            sModOut.avg.(varLon) = 'nan';
                            sModOut.avg.(varLat) = 'nan';
                            sModOut.avg.date = outDate;
                            sModOut.avg.indGage = indNNan2d;
                            sModOut.avg.fields = cell(0,1);
%                         sModOut.avg = struct('lon', nan, 'lat', nan, ...
%                             'date', outDate, 'indGage', (1:numel(sHydro.dem)), 'fields', cell(0,1));
                    end
                    
                    sModOut.avg.fields{end+1} = varCurr;
                    
                    if regexpbl(varCurr, 'mb') %Initialize gridded mass balance (uses start and end dates)
                        varMbDateStrt = [varCurr '_dateStart'];
                        varMbDateEnd  = [varCurr '_dateEnd'];
                        
                        %Assign mb dates:
                        [sModOut.avg.(varMbDateStrt), sModOut.avg.(varMbDateEnd)] = glac_measurement_dates(datesUse, 'dateGlac', sMeta);
                        
                        %Initialize output:
                        sModOut.avg.(varCurr) = nan([numel(sModOut.avg.(varMbDateStrt)(:,1)), 1], 'single');
                    else
                        sModOut.avg.(varCurr) = nan(szInitPt, 'single');
                    end
                elseif strcmpi(ptCurr,'all')
                    if ~isfield(sModOut,'all') || isempty(sModOut.all)
                        sModOut.all = struct;
                            sModOut.all.(varLon) = sHydro.(varLon);
                            sModOut.all.(varLat) = sHydro.(varLat);
                            sModOut.all.date = outDate;
                            sModOut.all.indGage = indNNan2d;
                            sModOut.all.fields = cell(0,1);
%                         sModOut.all = struct('lon', sHydro.(varLon), 'lat', sHydro.(varLat), ...
%                             'date', outDate, 'indGage', (1:numel(sHydro.dem)), 'fields', cell(0,1));
                    end
                    
                    if regexpbl(varCurr, 'mb') %Initialize gridded mass balance (uses start and end dates)
                        varMbDateStrt = [varCurr '_dateStart'];
                        varMbDateEnd  = [varCurr '_dateEnd'];

                        %Assign mb dates:
                        [sModOut.all.(varMbDateStrt), sModOut.all.(varMbDateEnd)] = glac_measurement_dates(datesUse, 'dateGlac', sMeta);
                        
                        %Initialize output:
                        sModOut.all.(varCurr) = nan([numel(sModOut.all.(varMbDateStrt)(:,1)), szInit3d(2:3)], 'single');
                    else
                        sModOut.all.(varCurr) = nan(szInit3d, 'single');
                    end
                    
                    %Add variable to list:
                    sModOut.all.fields{end+1} = varCurr;
                    %If being written to file, add path:
                    if sMeta.wrtGridOut == 1 && ~regexpbl(sMeta.runType,'calib')
                        sModOut.all.([varCurr '_path']) = fullfile(sMeta.foldWrtData, varCurr);
                    end
                else %Point output:
                    ptWrtCurr = ['pt' num2str(ptCurr)];
                    
                    %Check that the point is inside the current domain:
                    if iscell(sMeta.output{sMeta.siteCurr}{kk,2})
                        lonCurr = sMeta.output{sMeta.siteCurr}{kk,2}{ll}(1);
                        latCurr = sMeta.output{sMeta.siteCurr}{kk,2}{ll}(2);
                    else
                        lonCurr = sMeta.output{sMeta.siteCurr}{kk,2}(1);
                        latCurr = sMeta.output{sMeta.siteCurr}{kk,2}(2);
                    end

                    lonStep = nanmean(abs(diff(sHydro.(varLon))));
                    latStep = nanmean(abs(diff(sHydro.(varLat))));
                    lonEdg = [min(sHydro.(varLon)) - 0.5*lonStep, max(sHydro.(varLon)) + 0.5*lonStep];
                    latEdg = [max(sHydro.(varLat)) + 0.5*latStep, min(sHydro.(varLat)) - 0.5*latStep];

                    if lonCurr >= lonEdg(1) && lonCurr <= lonEdg(2) && latCurr <= latEdg(1) && latCurr >= latEdg(2) 
                        if ~isfield(sModOut, ptWrtCurr) || isempty(sModOut.(ptWrtCurr)) 
                            [r,c] = ind2sub(szMain,ptCurr);
                            sModOut.(ptWrtCurr) = struct;
                                sModOut.(ptWrtCurr).(varLon) = sHydro.(varLon)(c);
                                sModOut.(ptWrtCurr).(varLat) = sHydro.(varLat)(r);
                                sModOut.(ptWrtCurr).date = outDate;
                                sModOut.(ptWrtCurr).indGage = intersect(ptCurr, indNNan2d);
                                sModOut.(ptWrtCurr).fields = cell(0,1);
%                             sModOut.(ptWrt) ...
%                                 = struct('lon', sHydro.(varLon)(c), 'lat', sHydro.(varLat)(r), ...
%                                 'date', outDate, 'indGage', ptCurr, 'fields', cell(0,1));

                            %This may not be needed...
                            if isfield(sMeta, 'siteCurr')
                               sModOut.(ptWrtCurr).site = sMeta.siteCurr;
                            end
                        end
                        
                        if regexpbl(varCurr, 'mb') %Initialize gridded mass balance (uses start and end dates)
                            varMbDateStrt = [varCurr '_dateStart'];
                            varMbDateEnd  = [varCurr '_dateEnd'];

                            %Assign mb dates:
                            [sModOut.(ptWrtCurr).(varMbDateStrt), sModOut.(ptWrtCurr).(varMbDateEnd)] ...
                                = glac_measurement_dates(datesUse, 'dateGlac', sMeta);
                        
                            sModOut.(ptWrtCurr).(varCurr) = nan(numel(sModOut.avg.(varMbDateStrt)(:,1)), 1, 'single');
                        else
                            sModOut.(ptWrtCurr).(varCurr) = nan(szInitPt, 'single');
                        end
                        
                        sModOut.(ptWrtCurr).fields{end+1} = varCurr;
                    end
                   
                    
                    %The indices for ice points are potentially wrong because ice
                    %can have different grid than main
                    if iceGrid == 1
                        %Find ice grid cell for current output
                        %Lat:
                        rIce = find(sMeta.output{sMeta.siteCurr}{kk,2}{ll}(2) <= edgLat(1:end-1) & sMeta.output{sMeta.siteCurr}{kk,2}{ll}(2) >= edgLat(2:end));
                        %Lon:
                        cIce = find(sMeta.output{sMeta.siteCurr}{kk,2}{ll}(1) >= edgLon(1:end-1) & sMeta.output{sMeta.siteCurr}{kk,2}{ll}(1) <= edgLon(2:end));
                        
                        if isempty(rIce) || isempty(cIce)
                           error('print_model_state:iceOutside',['A model output point for ' varCurr ' falls outside the ice grid.']); 
                        end
                        indIce = sub2ind(szIce, rIce, cIce);
                        sModOut.(ptWrtCurr).iceLon = sCryo.iceLon(cIce);
                        sModOut.(ptWrtCurr).iceLat = sCryo.iceLat(rIce);
                        sModOut.(ptWrtCurr).indIce = indIce;
                    end
                end
            end
        end
    end %End of initialization

    
    %Indice of current date:    
    indDate = sMeta.indCurr - sMeta.indWrite + 1;
    
    %Get names of all points where output data requested:
    locOut = fieldnames(sModOut);
    fldsOut = cell(numel(locOut), 1);
    for kk = 1 : numel(locOut(:))
        fldsOut{kk} = sModOut.(locOut{kk}).fields;
    end
    

    %Populate output structure for each of the points:
    for kk = 1 : numel(locOut(:)) %Loop over grid pts to write to
        %Current point:
        ptWrtCurr = locOut{kk};
        
        for ll = 1 : numel(fldsOut{kk}) %Loop over data fields for current grid point
            nmCurr = char(fldsOut{kk}{ll});
                        
            %Indice for 2D area array:
            indAreaCurr = reshape(sModOut.(ptWrtCurr).indGage, [], 1);
            
            %CALCULATE INDICES AND EXTRACT MODELED DATA
            if any(strcmpi(fldsLand, nmCurr)) %INFORMATION IN "sLand"
                %Extract information:
                if strcmpi(ptWrtCurr, 'all') 
                    print_model_grid(sLand, nmCurr, ptWrtCurr, ...
                        indTsPrintCurr, sMeta, sHydro.(varLon), sHydro.(varLat));
                else
                    print_model_pt(sLand, nmCurr, ptWrtCurr, ...
                        indTsPrintCurr, sHydro.area, sModOut.(ptWrtCurr).indGage, indAreaCurr, sMeta);
                end
                
            elseif any(strcmpi(fldsAtm, nmCurr)) %INFORMATION IN "sAtm"
                %Extract information:
                if strcmpi(ptWrtCurr, 'all') 
                    print_model_grid(sAtm, nmCurr, ptWrtCurr, ...
                        indTsPrintCurr, sMeta, sHydro.(varLon), sHydro.(varLat));
                else
                    print_model_pt(sAtm, nmCurr, ptWrtCurr, ...
                        indTsPrintCurr, sHydro.area, sModOut.(ptWrtCurr).indGage, indAreaCurr, sMeta);
                end
                
            elseif any(strcmpi(fldsCryo, nmCurr)) && ~any(strcmpi(fldsmb, nmCurr)) %INFORMATION IN "sCryo" (other than mass balance)
                %Potentially use ice grid (can be different from main
                %grid)
                %Also, write boolean parameter to record whether or not ice
                %present at current location
                if regexpbl(nmCurr, 'ic')
                    %Check and record whether there is ice at requested point
                    indGageCurr = reshape(intersect(sModOut.(ptWrtCurr).indGage, find(sCryo.icx ~= 0)), [], 1);
                    if ~isempty(indGageCurr)
                        sModOut.(ptWrtCurr).icbl(indTsPrintCurr) = 1;
                    else
                        sModOut.(ptWrtCurr).icbl(indTsPrintCurr) = 0;
                    end
                    
                    if iceGrid == 1 %Ice grid seperate and current field is ice variable
                        szGrid = szIce;
                        indCurr = reshape(sModOut.(ptWrtCurr).indIce, [], 1);
                    else
                        szGrid = szMain;
                        indCurr = reshape(sModOut.(ptWrtCurr).indGage, [], 1);
                    end
                else
                    szGrid = szMain;
                    indCurr = reshape(sModOut.(ptWrtCurr).indGage, [], 1);
                end
                    
                %'casi' is not actually a field; therefore, need to check
                %corresponding fields
                switch nmCurr
                    case varCasi
                        fldCheck = 'scx';
                    case varGeodetic
                        fldCheck = 'icdwe';
                    case varStake %fieldObsCurr = {'icdwe','sndwe'}
                        fldCheck = 'sndwe';
                    otherwise
                        fldCheck = nmCurr;
                end
                
                %Define indices (if ice, using special indices defined above):
                if ndims(sCryo.(fldCheck)) == 3 %3D array
                    if isfield(sCryo, ['ind' fldCheck])
                        indInputTsCurr = sCryo.(['ind' fldCheck]);
                    else
                        indInputTsCurr = find(ismember(sCryo.(['date' fldCheck]), sMeta.dateCurr, 'rows') == 1);
                    end
                    
                    if isempty(indInputTsCurr)
                        error('groundwater_bucket:noPETcurr','No PET grid was calculated for the current time-step');
                    end
                    szCurr = size(sCryo.(fldCheck));
                    [gageRow, gageCol] = ind2sub(szGrid, indCurr);
                    indGageCurr = reshape(indInputTsCurr + (gageRow-1)*szCurr(1) + (gageCol-1)*szCurr(2)*szCurr(1), [], 1);
                    
                else %2D array
                    %Special case for ice grids:
                    if any(strcmpi(fldCheck, {'icdwe', 'iclr', 'icbl'})) && ~strcmpi(ptWrtCurr,'all')  
                        %Check and record whethere there is ice at requested point
                        indGageCurr = reshape(intersect(sModOut.(ptWrtCurr).indGage, find(sCryo.icx ~= 0)), [], 1);
                        indAreaCurr = reshape(intersect(indAreaCurr, find(sCryo.icx ~= 0)), [], 1);
                        %Create boolean field to display presence of ice at
                        %gage location:
                        if ~isfield(sModOut.(ptWrtCurr), 'icbl')
                            sModOut.(ptWrtCurr).icbl = zeros(numel(sMeta.date(:,1)) - sMeta.indWrite + 1, 1);
                        end
                        %Record presence of ice at gage location:
                        if ~isempty(indGageCurr)
                            sModOut.(ptWrtCurr).icbl(indTsPrintCurr) = 1;
                        else
                            sModOut.(ptWrtCurr).icbl(indTsPrintCurr) = 0;
                        end
                    else
                        indGageCurr = indCurr(:);
                    end
                end
                  
                %Extract information:
                switch nmCurr 
                    case varStake %fieldObsCurr = {'icdwe','sndwe'}
                        if strcmpi(ptWrtCurr, 'all')
                            warning('print_model_state:stakeAllGrid', 'The glacier stake observations are expected at a single point. An entire grid has not been programmed for.');
                        else
                            print_model_pt(sCryo.icdwe + sCryo.sndwe, nmCurr, ptWrtCurr, ...
                                indTsPrintCurr, sHydro.area, indGageCurr, indAreaCurr, sMeta);
                        end
                    case varGeodetic
                        if strcmpi(ptWrtCurr, 'all')
                            fldTemp = nan(szMain, 'single');
                            fldTemp(indNNan2d) = sCryo.icdwe(indNNan2d) + sCryo.sndwe(indNNan2d);
                            sModOut.(ptWrtCurr).(nmCurr)(indTsPrintCurr,:,:) = fldTemp;

                            if isfield(sModOut.(ptWrtCurr), [char(nmCurr) '_path'])
                                fileNm = fullfile(sMeta.foldWrtData, nmCurr, [char(file_nm(sMeta.region{sMeta.siteCurr}, nmCurr, sMeta.dateCurr)) '.nc']);
                                print_grid_NC_v2(fileNm, squeeze(sModOut.(ptWrtCurr).(nmCurr)(indTsPrintCurr,:,:)), nmCurr, sHydro.(varLon), sHydro.(varLat), sMeta.dateCurr, sMeta.dateCurr, 1);
                            end
                        else
                            fldTemp = nan(size(indGageCurr), 'single');
                            indUse = intersect(indGageCurr, indNNan2d);
                            indAreaUse = intersect(indAreaCurr, indNNan2d);
                            fldTemp(indUse) = sCryo.icdwe(indGageCurr(indUse)) + sCryo.sndwe(indGageCurr(indUse));
                            sModOut.(ptWrtCurr).(nmCurr)(indTsPrintCurr) ...
                                = nansum(fldTemp(indUse).*sHydro.area(indAreaUse(:)))...
                                /nansum(sHydro.area(indAreaUse(:)));
                        end
                    case varCasi %Special case for snow covered area:
                        if isfield(sCryo,'icdbr') %There is a debris field
                            optThresh = find_att(sMeta.global,'debris_opt_depth'); 
                            
                            %If debris cover field, only count non-debris covered ice
                            if strcmpi(ptWrtCurr,'all') 
                                casiTemp = nan(size(sCryo.scx), 'single');
                                casiTemp(indNNan2d) = 0;
                                %Use ice fraction at locations without
                                %debris
                                indSca = ~isnan(casiTemp) & (sCryo.icdbr < optThresh | isnan(sCryo.icdbr));
                                casiTemp(indSca) = sCryo.icx(indSca);
                                
                                casiTemp = 100*max(sCryo.scx, casiTemp);
                                casiTemp(isnan(sCryo.scx) | isnan(sCryo.icx)) = nan;
                                
                                sModOut.(ptWrtCurr).(nmCurr)(indTsPrintCurr,:,:) = casiTemp;

                                if isfield(sModOut.(ptWrtCurr), [char(nmCurr) '_path'])
                                    fileNm = fullfile(sMeta.foldWrtData, nmCurr, [char(file_nm(sMeta.region{sMeta.siteCurr}, nmCurr, sMeta.dateCurr)) '.nc']);
                                    print_grid_NC_v2(fileNm, squeeze(sModOut.(ptWrtCurr).(nmCurr)(indTsPrintCurr,:,:)), nmCurr, sHydro.(varLon), sHydro.(varLat), sMeta.dateCurr, sMeta.dateCurr, 1);
                                end
                            else   
                                casiTemp = zeros(size(indGageCurr), 'single');
                                indAreaUse = indAreaCurr;
%                                 casiTemp = nan(size(indGageCurr), 'single');
%                                 indSca = intersect(indGageCurr, indNNan2d);
%                                 indAreaUse = intersect(indAreaCurr, indNNan2d);
%                                 casiTemp(indSca) = 0;
                                
                                indSca = sCryo.icdbr(indGageCurr) < optThresh | isnan(sCryo.icdbr(indGageCurr));

                                casiTemp(indSca) = sCryo.icx(indGageCurr(indSca));
                                casiTemp = 100*max(sCryo.scx(indGageCurr),casiTemp);
                               
                                sModOut.(ptWrtCurr).(nmCurr)(indTsPrintCurr) ...
                                    = nansum((casiTemp)...
                                    .*sHydro.area(indAreaUse))/nansum(sHydro.area(indAreaUse));
                            end
                        else %No debris cover field
                            if strcmpi(ptWrtCurr,'all') 
                                casiTemp = nan(size(sCryo.scx), 'single');
                                casiTemp(indNNan2d) = 0;
                                %Use ice fraction at locations without
                                %debris
                                casiTemp(indNNan2d) = 100*max(sCryo.scx(indNNan2d), sCryo.icx(indNNan2d));
                                casiTemp(isnan(sCryo.scx) | isnan(sCryo.icx)) = nan;
                                
                                sModOut.(ptWrtCurr).(nmCurr)(indTsPrintCurr,:,:) = casiTemp;

                                if isfield(sModOut.(ptWrtCurr), [char(nmCurr) '_path'])
                                    fileNm = fullfile(sMeta.foldWrtData, nmCurr, [char(file_nm(sMeta.region{sMeta.siteCurr}, nmCurr, sMeta.dateCurr)) '.nc']);
                                    print_grid_NC_v2(fileNm, squeeze(sModOut.(ptWrtCurr).(nmCurr)(indTsPrintCurr,:,:)), nmCurr, sHydro.(varLon), sHydro.(varLat), sMeta.dateCurr, sMeta.dateCurr, 1);
                                end
                            else
                                casiTemp = 100*max(sCryo.scx(indGageCurr),sCryo.icx(indGageCurr));
                                indAreaUse = indAreaCurr;
                                
                                sModOut.(ptWrtCurr).(nmCurr)(indTsPrintCurr) ...
                                    = nansum((casiTemp)...
                                    .*sHydro.area(indAreaUse))/nansum(sHydro.area(indAreaUse));
                            end
                        end
                    otherwise
                        if strcmpi(ptWrtCurr, 'all')
                            print_model_grid(sCryo, nmCurr, ptWrtCurr, ...
                                indTsPrintCurr, sMeta, sHydro.(varLon), sHydro.(varLat));
                        else
                            print_model_pt(sCryo, nmCurr, ptWrtCurr, ...
                                indTsPrintCurr, sHydro.area, indGageCurr, indAreaCurr, sMeta, indNNan2d);
                        end
                end
            elseif any(strcmpi(fldsCryo, nmCurr)) && any(strcmpi(fldsmb, nmCurr)) %MASS BALANCE INFORMATION (stored in "sCryo")
                if regexpbl(fldsCryoAll, fldsmb)
                    %Difference with mass balance fields is that they are only
                    %calculated once per year
                    if regexpbl(nmCurr, 'ic')
                        fldMb = 'icmb';
                    elseif regexpbl(nmCurr, 'igrd')
                        fldMb = 'igrdmb';
                    else
                        error('printModelState:unknownIceFld',['The mass balance field ' nmCurr ' is not recognized.']);
                    end

                    if isfield(sMeta, 'dateGlac') 
                        %Find date to write to:
                        varMbDateStrt = [fldMb '_dateStart'];
                        varMbDateEnd  = [fldMb   '_dateEnd'];
                        keyboard
                        %Record mass balance if date corresponds to last day of
                        %mass balance year
                        if isequal(sMeta.dateCurr(2:end), sMeta.dateGlac) && any(sMeta.dateCurr(1) == sModOut.(ptWrtCurr).(varMbDateEnd)(:,1))
                            %Find current output mb indice
                            indMbCurr = find(ismember(sModOut.(ptWrtCurr).(varMbDateEnd), sMeta.dateCurr, 'rows'));
                            if ~isempty(indMbCurr)
                                if strcmpi(ptWrtCurr, 'all')
                                    fldTemp = nan(szMain, 'single');
                                    fldTemp(indNNan2d) = sCryo.(fldMb)(indNNan2d);
                                    sModOut.(ptWrtCurr).(nmCurr)(indMbCurr,:,:) = fldTemp;

                                    %Set indices outside domain to nan:
                                    %sModOut.(ptWrtCurr).(nmCurr) = array_time_slice_nan(sModOut.(ptWrtCurr).(nmCurr), indMbCurr);

                                    %Write to file
                                    if isfield(sModOut.(ptWrtCurr), [char(fldMb) '_path'])
                                        dateBndsMb = [sModOut.(ptWrtCurr).(varMbDateStrt)(indMbCurr,:); sModOut.(ptWrtCurr).(varMbDateEnd)(indMbCurr,:)];
                                        fileNm = fullfile(sMeta.foldWrtData, fldMb, [char(file_nm(sMeta.region{sMeta.siteCurr}, sModOut.(ptWrtCurr).fields{ll}, sModOut.(ptWrtCurr).date(indDate,:))) '.nc']);
                                        print_grid_NC_v2(fileNm, squeeze(sModOut.(ptWrtCurr).(nmCurr)(indMbCurr,:,:)), fldMb, sHydro.(varLon), sHydro.(varLat), dateBndsMb(end,:), dateBndsMb, 1, 'm.w.e./year');
                                    end
                                else
                                    if strcmpi(fldMb, 'igrdmb')
                                        error('printModelState:igrdNotYetProgrammed', ...
                                            ['Printing mb at specific indices of igrd ' ...
                                            '(high-res grid used for ice) has not been programmed. ' ...
                                            'This requires finding the correct spatial indices']);
                                    else
                                        print_model_pt(sCryo.(fldMb), nmCurr, ptWrtCurr, indTsPrintCurr, sHydro.area, indGageCurr, indAreaCurr, sMeta);
                                    end
                                end
                            end
                        end
                    end
                else %MB FIELD NOT FOUND
                    if indTsPrintCurr == 1
                        warning('backbone:noMbField', ['No mass balance '...
                            'field was found in the cryosphere structure.']);
                    end
                end
%             else %FIELD NOT FOUND
%                 if indTsPrintCurr == 1
%                     warning('backbone:unknownOutput', ['Output for ' ...
%                         char(39) char(sModOut.(ptWrtCurr).fields{ll}) char(39) ...
%                         'has been requested, but this is not a known output '...
%                         'type for the current model configuration.']);
%                 end
            end
        end
        
%         %Set values to nan at locations where dem is nan (values could be
%         %wrong at these locations):
%         if strcmpi(ptWrt, 'all')
%             indNan2d = find(isnan(sHydro.dem));
%             [nanRow, nanCol] = ind2sub(szMain, indNan2d);
%             
%             for ll = 1 : numel(fldsOut{kk})
%                 sz3d = size(sModOut.(ptWrt).(fldsOut{kk}{ll}));
%                 indNan3d = sub2ind(sz3d, indTsPrintCurr, nanRow, nanCol);
% %                 indNan3d = indTsPrintCurr + (nanRow-1)*sz3d(1) + (nanCol-1)*sz3d(2)*sz3d(1);
%                 sModOut.(ptWrt).(fldsOut{kk}{ll})(indNan3d) = nan;
%             end
%         end
    end
end

%Write output on select iterations to save time
if nargout > 0
    varargout{1} = sModOut;
end