function flow_Liston(sHydro, varargin)
%This function is modelled on Glen Liston's HydroFlow, described in
%Liston, G. E., & Mernild, S. H. (2012). Greenland freshwater runoff. 
%Part I: A runoff routing model for glaciated and nonglaciated landscapes 
%(HydroFlow). Journal of Climate, 25(17), 5997-6014.

%Currently I don't think this will work well for large watersheds and small
%timesteps because flow routes all the way through the watershed in one
%timestep.
%Also, only one previous time-step is considered.


global sLand

%!!!!
%THIS FUNCTION IS CURRENTLY NOT WORKING (DOES NOT CONTAIN REFERENCE TO
%sLand.mrro)!!!
%!!!!

%If not variable input argument, return parameters and do not proceed.
%Clark time lag:
if ~isempty(varargin(:))
    sMeta = varargin{1};
end

if sum(diag(sHydro.fdr)) > 0
   warning('flow_Clark:endoheroicFlow',['Some cells flow to themselves.  This may '...
       'cause an infinite loop or may not be handled properly.']); 
end

if ~isfield(sHydro,'tLagSlow')
   error('flow_Liston:tLagSlow',[char(39) 'flow_Liston' char(39) ...
       ' must be called by a function that creates a ' char(39) ...
       'tLagSlow' char(39) ' field']);
end


%Find dt (seconds):
dt = time2sec(1,sMeta.dt,sMeta.dateCurr); %Used for distributing previous time-steps streamflow (units = seconds)
% dtDays = eomday(sMeta.dateCurr(1),sMeta.dateCurr(2));
% indRun = (1:nGrid)';


%%CALCAULATE 'SLOW FLOW'
%'runslow' actually needs to be a 3D array (important for submonthly timestep)
if sLand.indCurr == 1
    sLand.runSlowP = zeros(size(sHydro.dem));
end


sLand.runSlow = exp(-dt./diag(sHydro.fdr*sLand.tlags,0)).*sLand.runSlowP(:) ...
    + (1-exp(-dt./diag(sHydro.fdr*sLand.tlags,0))).*sLand.mrro(:); %Units of meters
% ii = 1;
% while ii*dtDays < 7 %exp(-4) = 0.00091
%     sLand.runSlow = sLand.runSlow + exp(-ii*dtDays)*sLand.runSlowP;
%     ii = ii + 1;
% end

%Record current slowrunoff to be previous runoff in next loop.
sLand.runSlowP = sLand.runSlow; 


%%CALCULATE 'FAST FLOW'
if sLand.indCurr == 1
    sLand.runFastP = zeros(size(sHydro.dem));
end


[~, indOrd] = sort(sHydro.flowOrder(:));
sLand.runFast = zeros(size(sLand.flow));
for ii = 1 : numel(sLand.flow)
    sLand.runFast(indOrd(ii)) = ...
        exp(-dt/full(sHydro.fdr(indOrd(ii),:)*sLand.tlag(indOrd(ii),:)')).*sLand.runFastP(indOrd(ii)) ...
        + (1 - exp(-dt/full(sHydro.fdr(indOrd(ii),:)*sLand.tlag(indOrd(ii),:)'))).*(sLand.runSlowP(indOrd(ii)) + full(sLand.runFast(:)'*sHydro.fdr(:,indOrd(ii))));
end

sLand.runFastP = sLand.runFast;


%Add runoff to flow:
sLand.flow = sLand.runFast/dt;
% sLand.flow(sLand.indCurr,:,:) = sLand.runFast.*sHydro.area/dt;



