%% consensus_2b
% one w and tau parameter for all subjects, product space BF version
% uses PantoneSpring2015.mat

clear; close all;

%% constants
dataName = 'MistryLiljeholmExp1';
credibleInterval = 95;
fontSize = 14;
doPrint = true;

%% load data and graphics support
load(dataName, 'd');
try load pantoneSpring2015 pantone; catch load PantoneSpring2015 pantone; end

%% graphical model
modelName = 'consensus_2b';

% parameters to monitor
params = {'w', 'tauA', 'tauB', 'z'};

% generator for initialization% MCMC properties
% nChains = 4; nBurnin = 1e4; nSamples = 5e3; nThin = 100;  doParallel = 1;
% nChains = 6; nBurnin = 5e3; nSamples = 1e3; nThin = 100; doParallel = 1;
% nChains = 6; nBurnin = 5e3; nSamples = 2e3; nThin = 10; doParallel = 1;
nChains = 8; nBurnin = 1e3; nSamples = 1e4; nThin = 10;  doParallel = 1;
% nChains = 1; nBurnin = 0; nSamples = 100; nThin = 1;  doParallel = 0;

engine = 'jags';

generator = @()struct(...
   'w'    , rand(d.nSubjects, 1)        , ...
   'tauA' , ones(d.nSubjects, 1)        , ...
   'tauB' , ones(d.nSubjects, 1)        , ...
   'z'    , round(rand(d.nSubjects, 1)) );

% input for graphical model
data = struct(...
   'y'          , 2-d.decision      , ... % transform to Bernoulli 1 for majority and 0 for minority
   'nSubjects'  , d.nSubjects       , ...
   'nTrials'    , d.nTrials         , ...
   'm'          , d.values          , ...
   'c'          , d.majority        );

fileName = sprintf('storage/%s_%s', modelName, dataName);
if exist([fileName '.mat'], 'file')
   load(fileName, 'stats', 'chains', 'diagnostics', 'info');
else
   tic; % start clock
   [stats, chains, diagnostics, info] = callbayes(engine, ...
      'model'           ,  [modelName '.txt']                        , ...
      'data'            ,  data                                      , ...
      'outputname'      ,  'samples'                                 , ...
      'init'            ,  generator                                 , ...
      'datafilename'    ,  modelName                                 , ...
      'initfilename'    ,  modelName                                 , ...
      'scriptfilename'  ,  modelName                                 , ...
      'logfilename'     ,  modelName                                 , ...
      'nchains'         ,  nChains                                   , ...
      'nburnin'         ,  nBurnin                                   , ...
      'nsamples'        ,  nSamples                                  , ...
      'monitorparams'   ,  params                                    , ...
      'thin'            ,  nThin                                     , ...
      'workingdir'      ,  ['tmp/' modelName]                        , ...
      'verbosity'       ,  0                                         , ...
      'saveoutput'      ,  true                                      , ...
      'allowunderscores',  1                                         , ...
      'parallel'        ,  doParallel                                , ...
      'modules'         ,  {'dic'}                                   );
   fprintf('%s took %f seconds!\n', upper(engine), toc); % show timing
   save(fileName, 'stats', 'chains', 'diagnostics', 'info');
end

%% results

% convergence and summary
disp('Convergence statistics:')
grtable(chains, 1.05)

codatable(chains);
zMean = codatable(chains, 'z', @mean);
psBF = zMean./(1-zMean);
zMode = (psBF > 1); %codatable(chains, 'z', @mode);

save psBF psBF;

% gather means and cis from latent mixture, using only relevant samples
mnW = nan(d.nSubjects, 1);
mnTau = nan(d.nSubjects, 1);
ciW = nan(d.nSubjects, 2);
ciTau = nan(d.nSubjects, 2);
for idx = 1:d.nSubjects
   matchA = eval(sprintf('chains.z_%d(:) == 1;', idx));
   matchB = eval(sprintf('chains.z_%d(:) == 0;', idx));
   if zMode(idx) == 1
      mnW(idx) = 0;
      ciW(idx, 1:2) = [0 0];
      mnTau(idx) = eval(sprintf('mean(chains.tauB_%d(matchA));', idx));
      ciTau(idx, :) = prctile(chains.(sprintf('tauB_%d', idx))(matchA), [(100-credibleInterval)/2 100-(100-credibleInterval)/2]);
   elseif zMode(idx) == 0
      mnW(idx) = eval(sprintf('mean(chains.w_%d(matchB));', idx));
      ciW(idx, 1:2) = prctile(chains.(sprintf('w_%d', idx))(matchB), [(100-credibleInterval)/2 100-(100-credibleInterval)/2]);
      mnTau(idx) = eval(sprintf('mean(chains.tauA_%d(matchB));', idx));
      ciTau(idx, :) = prctile(chains.(sprintf('tauA_%d', idx))(matchB), [(100-credibleInterval)/2 100-(100-credibleInterval)/2]);
   end
end

% scatter plot
figure(2); clf; hold on;
set(gcf, ...
   'color'             , 'w'               , ...
   'units'             , 'normalized'      , ...
   'position'          , [0.2 0.2 0.4 0.6] , ...
   'paperpositionmode' , 'auto'            );

set(gca, ...
   'units'         , 'normalized'      , ...
   'position'      , [0.1 0.1 0.8 0.8] , ...
   'xlim'          , [-0.1 1]             , ...
   'xtick'         , 0:0.2:1           , ...
   'ylim'          , [0 max(ciTau(:))] , ...
   'ytick'         , 0:1:max(ciTau(:)) , ...
   'box'           , 'off'             , ...
   'tickdir'       , 'out'             , ...
   'layer'         , 'top'             , ...
   'ticklength'    , [0.01 0]          , ...
   'fontsize'      , fontSize          );
xlabel('w', 'fontsize', fontSize+2);
ylabel('tau', 'fontsize', fontSize+2);

rng(2); jiggle = nan(d.nSubjects, 1);
for idx = 1:d.nSubjects
   if zMode(idx) == 1
      jiggle(idx) = 1/2*(rand*0.1 - 0.05);
   else
      jiggle(idx) = 0;
   end
   plot(ones(1, 2)*mnW(idx)+jiggle(idx), ciTau(idx, :), '-', 'color', pantone.GlacierGray);
   plot(ciW(idx, :), ones(1, 2)*mnTau(idx), '-', 'color', pantone.GlacierGray);
end

for idx = 1:d.nSubjects
   plot(mnW(idx)+jiggle(idx), mnTau(idx), 'o', ...
      'markersize'      , 8                   , ...
      'markerfacecolor' , pantone.DuskBlue    , ...
      'markeredgecolor' , 'w'                 );
   text(mnW(idx)+jiggle(idx), mnTau(idx), sprintf('%d', idx), ...
      'fontsize'   , fontSize-2 , ...
      'horizontal' , 'left'     , ...
      'vertical'   , 'bottom'   , ...
      'layer'      , 'front'    );
end


% print
if doPrint
   print(sprintf('figures/%s%s%s.png', dataName, modelName, 'Scatter'), '-dpng', '-r300');
   print(sprintf('figures/%s%s%s.eps', dataName, modelName, 'Scatter'), '-depsc');
end

