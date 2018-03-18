function params = stblfit(X,varargin)
%PARAMS = STBLFIT(X) returns an estimate of the four parameters in a
% fit of the alpha-stable distribution to the data X.  The output 
% PARAMS is a 4 by 1 vector which contains the estimates of the 
% characteristic exponent ALPHA, the skewness BETA, the scale GAMMA and 
% location DELTA.  
%
%PARAMS = STBLFIT(X,METHOD) Specifies the algorithm used to
% estimate the parameters.  The choices for METHOD are
%        'ecf' - Fits the four parameters to the empirical characteristic
%               function estimated from the data.  This is the default. 
%               Based on Koutrouvelis (1980,1981), see [1],[2] below.
% 'percentile' - Fits the four parameters using various 
%                percentiles of the data X.  This is faster than 'ecf', 
%                however studies have shown it to be slightly less 
%                accurate in general.  
%                Based on McCulloch (1986), see [2] below.
%  
%PARAMS = STBLFIT(...,OPTIONS) specifies options used in STBLFIT.  OPTIONS
% must be an options stucture created with the STATSET function.  Possible
% options are
%       'Display' - When set to 'iter', will display the values of 
%                   alpha,beta,gamma and delta in each
%                   iteration.  Default is 'off'.
%       'MaxIter' - Specifies the maximum number of iterations allowed in
%                   estimation. Default is 5.
%       'TolX'    - Specifies threshold to stop iterations. Default is
%                   0.01.
%
%   See also: STBLRND, STBLPDF, STBLCDF, STBLINV
%
% References:
%   [1] I. A. Koutrouvelis (1980)
%       "Regression-Type Estimation of the Paramters of Stable Laws.
%       JASA, Vol 75, No. 372
%
%   [2] I. A. Koutrouvelis (1981)
%       "An Iterative Procedure for the estimation of the Parameters of
%       Stable Laws"
%       Commun. Stat. - Simul. Comput. 10(1), pages 17-28
%
%   [3] J. H. McCulloch (1986)
%       "Simple Consistent Estimators of Stable Distribution Parameters"
%       Cummun. Stat. Simul. Comput. 15(4)
%
%   [4] A. H. Welsh (1986)
%       "Implementing Empirical Characteristic Function Procedures"
%       Statistics & Probability Letters Vol 4, pages 65-67    


% ==== Gather additional options
dispit = false;
maxiter = 5;
tol = .01;
if ~isempty(varargin) 
    if isstruct(varargin{end})
        opt = varargin{end};
        try
            dispit = opt.Display;
        catch ME
            error('OPTIONS must be a structure created with STATSET');
        end
        if ~isempty(opt.MaxIter)
            maxiter = opt.MaxIter;
        end
        if ~isempty(opt.TolX)
            tol = opt.TolX;
        end
    end
end

if strcmp(dispit,'iter')
    dispit = true;
    fprintf('    iteration\t    alpha\t    beta\t  gamma\t\t  delta\n');
    dispfmt = '%8d\t%14g\t%8g\t%8g\t%8g\n';
end

% === Find which method.
if any(strcmp(varargin,'percentile'))    
    maxiter = 0; % This is McCulloch's percentile method
end


% ==== Begin estimation =====
N = numel(X); % data size

% function handle to compute empirical char. functions  
I = sqrt(-1);
phi = @(theta,data) 1/numel(data) * sum( exp( I * ...
    reshape(theta,numel(theta),1) *...
    reshape(data,1,numel(data)) ) , 2);

% Step 1 - Obtain initial estimates of parameters using McCulloch's method
%          then standardize data
[alpha beta] = intAlpBet(X);
[gam delta ] = intGamDel(X,alpha,beta);

if gam==0
    % Use standard deviation as initial guess
    gam = std(X);
end
    
s = (X - delta)/gam;


if dispit
    fprintf(dispfmt,0,alpha,beta,gam,delta);
end
  
% Step 2 - Iterate until convergence
alphaold = alpha; 
deltaold = delta;
diffbest = inf;
for iter = 1:maxiter
    
    % Step 2.1 - Regress against ecf to refine estimates of alpha & gam
    %            After iteration 1, use generalized least squares 
    if iter <= 2
        K = chooseK(alpha,N);
        t = (1:K)*pi/25;
        w = log(abs(t));
    end
    
    y = log( - log( abs(phi(t,s)).^2 ) );
    
    if iter == 1  % use ordinary least squares regression
        ell = regress(y,[w' ones(size(y))]);
        alpha = ell(1); 
        gamhat = (exp(ell(2))/2)^(1/alpha);
        gam = gam * gamhat;
    else          % use weighted least squares regression
        sig = charCov1(t ,N, alpha , beta, 1);
        try
            ell = lscov([w' ones(size(y))],y,sig);
        catch   % In case of badly conditioned covariance matrix, just use diagonal entries
            try
                ell = lscov([w' ones(size(y))],y,eye(K).*(sig+eps));
            catch
                break
            end
        end 
        alpha = ell(1); 
        gamhat = (exp(ell(2))/2)^(1/alpha);
        gam = gam * gamhat;
    end
     
    % Step 2.2 - Rescale data by estimated scale, truncate
    s = s/gamhat;
    alpha = max(alpha,0);
    alpha = min(alpha,2);
    beta = min(beta,1);
    beta = max(beta,-1);
    gam = max(gam,0);
    
    % Step 2.3 - Regress against ecf to refine estimates of beta, delta
    %            After iteration 1, use generalized least squares        
    if iter <=  2
        L = chooseL(alpha,N);
        % To ensure g is continuous, find first zero in real part of ecf
        A = efcRoot(s);
        u = (1:L)*min(pi/50,A/L);  
    end
    
    ecf = phi(u,s);
    U = real(ecf);
    V = imag(ecf);
    g = atan2(V,U);
    if iter == 1  % use ordinary least squares
        ell = regress(g, [u',  sign(u').*abs(u').^alpha]);
        beta =  ell(2)/tan(alpha*pi/2) ;
        delta = delta + gam* ell(1) ;
    else         % use weighted least squares regression
        sig = charCov2(u ,N, alpha , beta, 1);
        try
            ell = lscov([u',  sign(u').*abs(u').^alpha],g,sig);
        catch % In case of badly conditioned covariance matrix, use diagonal entries
            try
                ell = lscov([u',  sign(u').*abs(u').^alpha],g,eye(L).*(sig+eps));
            catch
                break
            end
        end
        beta =  ell(2)/tan(alpha*pi/2) ;
        delta = delta + gam* ell(1) ;   
    end
        
    % Step 2.4 Remove estimated shift
    s = s - ell(1);

    % display 
    if dispit
        fprintf(dispfmt,iter,alpha,beta,gam,delta);
    end
    
    % Check for blow-up
    if any(isnan([alpha, beta, gam, delta]) | isinf([alpha, beta, gam, delta]))
        break
    end
    
    
    % Step 2.5 Check for convergence, keep track of parameters with
    % smallest 'diff'
    diff = (alpha - alphaold)^2 + (delta - deltaold)^2;
    if abs(diff) < diffbest
        bestparams = [alpha; beta; gam; delta];
        diffbest = diff;
        if diff < tol
            break;
        end
    end
    
    
    
    
    alphaold = alpha;
    deltaold = delta;
    
end

% Pick best
if maxiter > 0 && iter >= 1 
    alpha = bestparams(1);
    beta = bestparams(2);
    gam = bestparams(3);
    delta = bestparams(4);
end

% Step 3 - Truncate if necessary
alpha = max(alpha,0);
alpha = min(alpha,2);
beta = min(beta,1);
beta = max(beta,-1);
gam = max(gam,0);

params = [alpha; beta; gam; delta];

end % End stblfit

%===============================================================
%===============================================================

function [alpha beta] = intAlpBet(X)
% Interpolates Tables found in MuCulloch (1986) to obtain a starting 
% estimate of alpha and beta based on percentiles of data X

% Input tables
nuA = [2.439 2.5 2.6 2.7 2.8 3.0 3.2 3.5 4.0 5.0 6.0 8.0 10 15 25];
nuB = [0 .1 .2 .3 .5 .7 1];
[a b] = meshgrid( nuA , nuB );
alphaTab=  [2.000 2.000 2.000 2.000 2.000 2.000 2.000;...
             1.916 1.924 1.924 1.924 1.924 1.924 1.924;...
             1.808 1.813 1.829 1.829 1.829 1.829 1.829;...
             1.729 1.730 1.737 1.745 1.745 1.745 1.745;...
             1.664 1.663 1.663 1.668 1.676 1.676 1.676;...
             1.563 1.560 1.553 1.548 1.547 1.547 1.547;...
             1.484 1.480 1.471 1.460 1.448 1.438 1.438;...
             1.391 1.386 1.378 1.364 1.337 1.318 1.318;...
             1.279 1.273 1.266 1.250 1.210 1.184 1.150;...
             1.128 1.121 1.114 1.101 1.067 1.027 0.973;...
             1.029 1.021 1.014 1.004 0.974 0.935 0.874;...
             0.896 0.892 0.887 0.883 0.855 0.823 0.769;...
             0.818 0.812 0.806 0.801 0.780 0.756 0.691;...
             0.698 0.695 0.692 0.689 0.676 0.656 0.595;...
             0.593 0.590 0.588 0.586 0.579 0.563 0.513]';
betaTab=  [ 0.000 2.160 1.000 1.000 1.000 1.000 1.000;...
            0.000 1.592 3.390 1.000 1.000 1.000 1.000;...
            0.000 0.759 1.800 1.000 1.000 1.000 1.000;...
            0.000 0.482 1.048 1.694 1.000 1.000 1.000;...
            0.000 0.360 0.760 1.232 2.229 1.000 1.000;...
            0.000 0.253 0.518 0.823 1.575 1.000 1.000;...
            0.000 0.203 0.410 0.632 1.244 1.906 1.000;...
            0.000 0.165 0.332 0.499 0.943 1.560 1.000;...
            0.000 0.136 0.271 0.404 0.689 1.230 2.195;...
            0.000 0.109 0.216 0.323 0.539 0.827 1.917;...
            0.000 0.096 0.190 0.284 0.472 0.693 1.759;...
            0.000 0.082 0.163 0.243 0.412 0.601 1.596;...
            0.000 0.074 0.147 0.220 0.377 0.546 1.482;...
            0.000 0.064 0.128 0.191 0.330 0.478 1.362;...
            0.000 0.056 0.112 0.167 0.285 0.428 1.274]';
   
% Calculate percentiles
Xpcts = prctile(X,[95 75 50 25 5]); 
nuAlpha = (Xpcts(1) - Xpcts(5))/(Xpcts(2) - Xpcts(4));
nuBeta = (Xpcts(1) + Xpcts(5) - 2*Xpcts(3))/(Xpcts(1) - Xpcts(5));
% Bring into range
if nuAlpha < 2.4390
    nuAlpha = 2.439 + 1e-12;
elseif nuAlpha > 25
    nuAlpha = 25 - 1e-12;
end

s = sign(nuBeta); 

% Get alpha
alpha = interp2(a,b,alphaTab,nuAlpha,abs(nuBeta));

% Get beta
beta = s * interp2(a,b,betaTab,nuAlpha,abs(nuBeta));

% Truncate beta if necessary
if beta>1
    beta = 1;
elseif beta < -1
    beta =-1;
end

    
end

function [gam delta] = intGamDel(X,alpha,beta)
% Uses McCulloch's Method to obtain scale and location of data X given
% estimates of alpha and beta.

% Get percentiles of data and true percentiles given alpha and beta;
Xpcts = prctile(X,[75 50 25]);

% If alpha is very close to 1, truncate to avoid numerical instability.
warning('off','stblcdf:ScaryAlpha');
warning('off','stblpdf:ScaryAlpha');
if abs(alpha - 1) < .02
    alpha = 1;
end

% With the 'quick' option, these are equivalent to McCulloch's tables 
Xquart = stblinv([.75 .25],alpha,beta,1,0,'quick');
Xmed = stblinv(.5,alpha,beta,1,-beta*tan(pi*alpha/2),'quick');

% Obtain gamma as ratio of interquartile ranges
gam = (Xpcts(1) - Xpcts(3))/(Xquart(1) - Xquart(2));

% Obtain delta using median of shifted data and estimate of gamma
zeta = Xpcts(2) - gam * Xmed;
delta = zeta - beta*gam*tan(alpha*pi/2);

end

function K = chooseK(alpha,N)
    % Interpolates Table 1 in [1] to calculate optimum K given alpha and N
    
    % begin parameters into correct ranges.
    alpha = max(alpha,.3);
    alpha = min(alpha,1.9);
    N = max(N,200);
    N = min(N,1600);
    a = [1.9, 1.5: -.2: .3];
    n = [200 800 1600]; 
    [X Y] = meshgrid(a,n);
    Kmat = [ 9   9   9 ; ...
            11  11  11 ; ...
            22  16  14 ; ...
            24  18  15 ; ...
            28  22  18 ; ...
            30  24  20 ; ...
            86  68  56 ; ...
            134 124 118  ];    
     K = round(interp2(X,Y,Kmat',alpha,N,'linear'));
    
                
end
               
function L = chooseL(alpha,N)
    % Interpolates Table 2 in [1] to calculate optimum L given alpha and N
    
    alpha = max(alpha,.3);
    alpha = min(alpha,1.9);
    N = max(N,200);
    N = min(N,1600);
    a = [1.9, 1.5, 1.1:-.2:.3];
    n = [200 800 1600]; 
    [X Y] = meshgrid(a,n);
    Lmat = [ 9  10  11 ; ...
            12  14  15 ; ...
            16  18  17 ; ...
            14  14  14 ; ...
            24  16  16 ; ...
            40  38  36 ; ...
            70  68  66 ]; 
    L = round(interp2(X,Y,Lmat',alpha,N,'linear'));
     
end
        
function A = efcRoot(X)
% An iterative procedure to find the first positive root of the real part
% of the empirical characteristic function of the data X. Based on [4].

N = numel(X);
U = @(theta) 1/N * sum( cos(   ...
    reshape(theta,numel(theta),1) *...
      reshape(X,1,N)       ) , 2 );  % Real part of ecf
m = mean(abs(X)); 
A = 0;
val = U(A);
iter1 = 0;
while abs(val) > 1e-3 && iter1 < 10^4
    A = A + val/m;
    val = U(A);
    iter1 = iter1 + 1;
end

end    

function sig = charCov1(t ,N, alpha , beta,gam)
% Compute covariance matrix of y = log (- log( phi(t) ) ), where phi(t) is 
% ecf of alpha-stable random variables. Based on Theorem in [2].

    K = length(t);
    w = tan(alpha*pi/2);
    calpha = gam^alpha;
    
    Tj = repmat( t(:) , 1 , K);
    Tk = repmat( t(:)'  , K , 1);
    Tjalpha = abs(Tj).^alpha;
    Tkalpha = abs(Tk).^alpha;
    TjxTk = abs(Tj .* Tk);
    TjpTk = Tj + Tk ;
    TjpTkalpha = abs(TjpTk).^alpha;
    TjmTk = Tj - Tk ;
    TjmTkalpha = abs(TjmTk).^alpha;
    
    A = calpha*( Tjalpha + Tkalpha - TjmTkalpha);
    B = calpha * beta *...
        (-Tjalpha .* sign(Tj) * w ...
        + Tkalpha .* sign(Tk) * w ...
        + TjmTkalpha .* sign(TjmTk) * w) ;
    D = calpha * (Tjalpha + Tkalpha - TjpTkalpha);
    E = calpha * beta *...
        ( Tjalpha .* sign(Tj) * w ...    
        + Tkalpha .* sign(Tk) * w ...
        - TjpTkalpha .* sign(TjpTk) * w);
    
    sig = (exp(A) .* cos(B) + exp(D).*cos(E) - 2)./...
          ( 2 * N * gam^(2*alpha) * TjxTk.^alpha);
    

end

function sig = charCov2(t ,N, alpha , beta, gam)
% Compute covariance matrix of z = Arctan(imag(phi(t))/real(phi(t)), 
% where phi(t) is ecf of alpha-stable random variables.
% Based on Theorem in [2].    
    K = length(t);
    w = tan(alpha*pi/2);
    calpha = gam^alpha;
    
    Tj = repmat( t(:) , 1 , K);
    Tk = repmat( t(:)'  , K , 1);
    Tjalpha = abs(Tj).^alpha;
    Tkalpha = abs(Tk).^alpha;
    TjpTk = Tj + Tk ;
    TjpTkalpha = abs(TjpTk).^alpha;
    TjmTk = Tj - Tk ;
    TjmTkalpha = abs(TjmTk).^alpha;
    
    B = calpha * beta *...
        (-Tjalpha .* sign(Tj) * w ...
        + Tkalpha .* sign(Tk) * w ...
        + TjmTkalpha .* sign(TjmTk) * w) ; 
    E = calpha * beta *...
        ( Tjalpha .* sign(Tj) * w ...    
        + Tkalpha .* sign(Tk) * w ...
        - TjpTkalpha .* sign(TjpTk) * w);
    F = calpha * (Tjalpha + Tkalpha);
    G = -calpha * TjmTkalpha;
    H = -calpha * TjpTkalpha;
    
    sig = exp(F) .*(exp(G) .* cos(B) - exp(H) .* cos(E))/(2*N);

    

end

function x = stblinv(u,alpha,beta,gam,delta,varargin)
%X = STBLINV(U,ALPHA,BETA,GAM,DELTA) returns values of the inverse CDF of
% the alpha-stable distribution with characteristic exponent ALPHA, skewness
% BETA, scale GAM, and location DELTA at the values in the array U.   
%
% This alogrithm uses a combination of Newton's method and the bisection 
% method to compute the inverse cdf to a tolerance of 1e-6;
%
% X = STBLINV(U,ALPHA,BETA,GAM,DELTA,'quick') returns a linear interpolated
% approximation of the inverse CDF based on a table of pre-calculated
% values.  The table contains exact values at
%   ALPHA = [.1 : .1: 2]
%   BETA  = [0: .2 :  1]
%   U     = [ .1 : .1 : .9 ]
% If U < .1 or U > .9, the 'quick' option approximates the CDF with its 
% asymptotic form which is given in [1], page 16, Property 1.2.15.  Results
% for U outside the interval [.1:.9] may vary.
% 
% If abs(ALPHA - 1) < 1e-5,  ALPHA is rounded to 1.
%
% See also:  STBLRND, STBLPDF, STBLCDF, STBLFIT
%
% Reference:
%  [1] G. Samorodnitsky & M. S. Taqqu (1994)
%      "Stable Non-Gaussian Random Processes, Stochastic Models with 
%       Infinite Variance"  Chapman & Hall
%
if nargin < 5
    error('stblcdf:TooFewInputs','Requires at least five input arguments.'); 
end

% Check parameters
if alpha <= 0 || alpha > 2 || ~isscalar(alpha)
    error('stblcdf:BadInputs',' "alpha" must be a scalar which lies in the interval (0,2]');
end
if abs(beta) > 1 || ~isscalar(beta)
    error('stblcdf:BadInputs',' "beta" must be a scalar which lies in the interval [-1,1]');
end
if gam < 0 || ~isscalar(gam)
    error('stblcdf:BadInputs',' "gam" must be a non-negative scalar');
end
if ~isscalar(delta)
    error('stblcdf:BadInputs',' "delta" must be a scalar');
end

if (1e-5 < abs(alpha - 1)  && abs(alpha - 1) < .02) || alpha < .02
    warning('stblcdf:ScaryAlpha',...
        'Difficult to approximate cdf for alpha close to 0 or 1')
end

quick = false;
if ~isempty(varargin)
    if strcmp(varargin{1},'quick')
        quick = true;
    end
end

% For Newton's Method
itermax = 30;
maxbisecs = 30;
tol = 1e-8;

% Return NaN for out of range parameters or probabilities.
u(u < 0 | 1 < u) = NaN;

% Check to see if you are in a simple case, if so be quick.
if alpha == 2                  % Gaussian distribution 
    x = - 2 .* erfcinv(2*u);
    x = x*gam + delta;    %  
elseif alpha==1 && beta == 0   % Cauchy distribution
    x =  tan(pi*(u - .5) );   
    x = x*gam + delta;
elseif alpha == .5 && abs(beta) == 1 % Levy distribution 
    x = .5 * beta ./(erfcinv(u)).^2;
    x = x*gam + delta;
else                % Gen. Case
    
    % Flip sign of beta if necessary
    if beta < 0
        signBeta = -1;
        u = 1-u;
        beta = -beta;
    else
        signBeta = 1;
    end
    
    % Calculate additional shift for (M) parameterization 
    if abs(alpha - 1) > 1e-5
        deltaM = -beta * tan(alpha*pi/2); % 
    else
        deltaM = 0;
    end
     
    x = intGuess(alpha,beta,u);
    if ~quick
        % Newton's Method
        F = stblcdf(x,alpha,beta,1,deltaM) - u;
        diff = max(abs(F),0); % max incase of NaNs
        bad = diff > tol;
        iter = 1;
        Fold = F;
        xold = x; 
        while any(bad(:)) && iter < itermax 
            
            % Perform Newton step 
            % If Fprime = 0, step closer to origin instead
            Fprime = stblpdf(x(bad),alpha,beta,1,deltaM,1e-8);
            x(bad) = x(bad) - F(bad) ./ Fprime;
            blowup = isinf(x) | isnan(x);
            if ~isempty(blowup) 
                x(blowup) = xold(blowup) / 2;
            end

            F(bad) = stblcdf(x(bad),alpha,beta,1,deltaM) - u(bad);

            % Make sure we are getting closer, if not, do bisections until
            % we do.
            nocvg = abs(F) > 1.1*abs(Fold);
            bisecs = 0;
            while any(nocvg(:)) && (bisecs < maxbisecs)
                x(nocvg) = .5*(x(nocvg) + xold(nocvg));
                F(nocvg) = stblcdf(x(nocvg),alpha,beta,1,deltaM) - u(nocvg);
                nocvg = abs(F) > 1.1*abs(Fold);
                bisecs = bisecs + 1;
            end

            % Test for convergence
            diff = max(abs(F),0); % max incase of NaNs
            bad = diff > tol;

            % Save for next iteration
            xold = x;
            Fold = F;
            iter = iter + 1;
        end
    end
      
    % Un-standardize
    if abs(1 - alpha) > 1e-5
        x = signBeta*(x - deltaM)*gam + delta;
    else
        x = signBeta*(x*gam + (2/pi) * beta * gam * log(gam)) + delta;
    end
       
end


end



%===================================================================
%===================================================================
%===================================================================

function X0 = intGuess(alpha,beta,u)
% Look-up table of percentiles of standard stable distributions
% If .1 < u < .9, Interpolatates tabulated values to obtain initial guess
% If u < .1 or u > .9 uses asymptotic formulas to make a starting guess 

utemp = u(:);
X0 = zeros(size(utemp));
alpha = max(alpha,.1);
if beta == 1
    utemp(utemp < .1) = .1;  % bring these into table range 
end                          % since asyp. formulas don't apply if beta=1.
 
high = (utemp > .9);  
low = (utemp < .1);
middle = ~high & ~low;

% Use asymptotic formulas to guess high and low
if any(high(:) | low(:))
    if alpha ~= 1 
        C = (1-alpha) / ( gamma(2 - alpha) * cos(pi*alpha/2) );
    else
        C = 2/pi;
    end
    X0(high) = ( (1-u(high))/(C * .5 * (1 + beta)) ).^(-1/alpha); 
    X0(low)  = -(u(low)/(C * .5 * (1 - beta))).^(-1/alpha);
end

% Use pre-calculated lookup table
if any(middle(:))
    [Alp,Bet,P] = meshgrid(.1:.1:2 , 0:.2:1 , .1:.1:.9 ); 
    stblfrac = zeros(6,20,9);
    stblfrac(:,1:5,1) = ...  % 
      [-1.890857122067030e+006   -1.074884919696010e+003   -9.039223076384694e+001   -2.645987890965098e+001   -1.274134564492298e+001;...
       -1.476366405440763e+005   -2.961237538429159e+002   -3.771873580263473e+001   -1.357404219788403e+001   -7.411052003232824e+000;...
       -4.686998894118387e+003   -5.145071882481552e+001   -1.151718246460839e+001   -5.524535336243413e+000   -3.611648531595958e+000;...
       -2.104710824345458e+001   -3.379418096823576e+000   -1.919928049616870e+000   -1.508399002681057e+000   -1.348510542803496e+000;...
       -1.267075422596289e-001   -2.597188113311268e-001   -4.004811495862077e-001   -5.385024279816432e-001   -6.642916520777534e-001;...
       -1.582153175255304e-001   -3.110425775503970e-001   -4.383733961816599e-001   -5.421475800719634e-001   -6.303884905318050e-001];
    stblfrac(:,6:10,1) = ...
      [-7.864009406553024e+000   -5.591791397752695e+000   -4.343949435866958e+000   -3.580521076832391e+000   -3.077683537175253e+000;...
       -4.988799898398770e+000   -3.787942909197120e+000   -3.103035515608863e+000   -2.675942594722292e+000   -2.394177022026705e+000;...
       -2.762379160216148e+000   -2.313577186902494e+000   -2.052416861482463e+000   -1.893403771865641e+000   -1.796585983161395e+000;...
       -1.284465355994317e+000   -1.267907903071982e+000   -1.279742001004255e+000   -1.309886183701422e+000   -1.349392554642457e+000;...
       -7.754208907962602e-001   -8.732998811318613e-001   -9.604322013853581e-001   -1.039287445657237e+000   -1.111986321525904e+000;...
       -7.089178961038225e-001   -7.814055112235459e-001   -8.502117698317242e-001   -9.169548634355569e-001   -9.828374636178471e-001];
    stblfrac(:,11:15,1) = ...
      [-2.729262880847457e+000   -2.479627528870857e+000   -2.297138304998905e+000   -2.162196365947914e+000   -2.061462692277420e+000;...
       -2.202290611202918e+000   -2.070075681428623e+000   -1.979193969170630e+000   -1.917168989568703e+000   -1.875099179801364e+000;...
       -1.740583121589162e+000   -1.711775396141753e+000   -1.700465158047576e+000   -1.700212465596452e+000   -1.707238269631509e+000;...
       -1.391753942957071e+000   -1.434304119387730e+000   -1.476453646904256e+000   -1.518446568503842e+000   -1.560864595722380e+000;...
       -1.180285915835185e+000   -1.245653509438976e+000   -1.309356535558631e+000   -1.372547245869795e+000   -1.436342854982504e+000;...
       -1.048835660976022e+000   -1.115815771583362e+000   -1.184614345408666e+000   -1.256100352867799e+000   -1.331235978799527e+000];
    stblfrac(:,16:20,1) = ...
       [-1.985261982958637e+000   -1.926542865732525e+000   -1.880296841910385e+000   -1.843044812063057e+000   -1.812387604873646e+000;...
       -1.846852935880107e+000   -1.828439745755405e+000   -1.817388844989596e+000   -1.812268962543248e+000   -1.812387604873646e+000;...
       -1.719534615317151e+000   -1.736176665562027e+000   -1.756931455967477e+000   -1.782079727531726e+000   -1.812387604873646e+000;...
       -1.604464355709833e+000   -1.650152416312346e+000   -1.699029550621646e+000   -1.752489822658308e+000   -1.812387604873646e+000;...
       -1.501904088536648e+000   -1.570525854475943e+000   -1.643747672313277e+000   -1.723509779436442e+000   -1.812387604873646e+000;...
       -1.411143947581252e+000   -1.497190629447853e+000   -1.591104422133556e+000   -1.695147748117837e+000   -1.812387604873646e+000];

    stblfrac(:,1:5,2) = ...
       [-4.738866777987500e+002   -1.684460387562537e+001   -5.619926961081743e+000   -3.281734135829228e+000   -2.397479160864619e+000;...
       -2.185953347160669e+001   -3.543320127025984e+000   -1.977029667649595e+000   -1.507632281031653e+000   -1.303310228044346e+000;...
       -2.681009914911080e-001   -4.350930213152404e-001   -5.305212880041126e-001   -6.015232065896753e-001   -6.620641788021128e-001;...
       -9.503065419472154e-002   -1.947070824738389e-001   -2.987136341021804e-001   -3.973064532664002e-001   -4.838698271554803e-001;...
       -1.264483719244014e-001   -2.437377726529247e-001   -3.333750988387906e-001   -4.016893641684894e-001   -4.577316520822721e-001;...
       -1.526287733702501e-001   -2.498255243669921e-001   -3.063859169446500e-001   -3.504924054764082e-001   -3.911254396222550e-001];
    stblfrac(:,6:10,2) = ...
       [-1.959508008521143e+000   -1.708174380583835e+000   -1.550822278332538e+000   -1.447013328833974e+000   -1.376381920471173e+000;...
       -1.199548019673933e+000   -1.144166826374866e+000   -1.115692821970145e+000   -1.103448361903579e+000   -1.101126400280696e+000;...
       -7.174026993828067e-001   -7.694003004766365e-001   -8.178267862332173e-001   -8.615585464741182e-001   -9.003104216523169e-001;...
       -5.579448431371428e-001   -6.215822273361273e-001   -6.771753949313707e-001   -7.267793058476849e-001   -7.720164852674839e-001;...
       -5.069548741156986e-001   -5.523620701546919e-001   -5.956554729327528e-001   -6.378655338388568e-001   -6.796745661620428e-001;...
       -4.309657384679277e-001   -4.709130419301468e-001   -5.113624096299824e-001   -5.525816075847192e-001   -5.948321009341774e-001];
    stblfrac(:,11:15,2) = ...
      [-1.327391983207241e+000   -1.292811209009340e+000   -1.267812588403031e+000   -1.249132310044230e+000   -1.234616432819130e+000;...
       -1.104531584444055e+000   -1.110930462397609e+000   -1.118760810700929e+000   -1.127268239360369e+000   -1.136171639806347e+000;...
       -9.347554970493899e-001   -9.658656088352816e-001   -9.945788535033495e-001   -1.021718797792234e+000   -1.048005562158225e+000;...
       -8.141486817740096e-001   -8.541760575495752e-001   -8.929234555236560e-001   -9.311104141820112e-001   -9.694099704722252e-001;...
       -7.215886443544494e-001   -7.640354693071291e-001   -8.074261467088205e-001   -8.522003643607233e-001   -8.988670244927735e-001;...
       -6.384119892912432e-001   -6.836776839822375e-001   -7.310612144698296e-001   -7.810921001396979e-001   -8.344269070778757e-001];
    stblfrac(:,16:20,2) = ...
       [-1.222879780072203e+000   -1.213041554808853e+000   -1.204541064608597e+000   -1.197016952370690e+000   -1.190232162899989e+000;...
       -1.145449097190615e+000   -1.155224344271089e+000   -1.165719407748303e+000   -1.177246763148178e+000   -1.190232162899989e+000;...
       -1.074094694885961e+000   -1.100624477495892e+000   -1.128270402039747e+000   -1.157812818875688e+000   -1.190232162899989e+000;...
       -1.008502023575024e+000   -1.049129636922346e+000   -1.092166845038550e+000   -1.138712425453996e+000   -1.190232162899989e+000;...
       -9.480479125009214e-001   -1.000533792677121e+000   -1.057363229272293e+000   -1.119941850176443e+000   -1.190232162899989e+000;...
       -8.918931068397437e-001   -9.545526172382969e-001   -1.023797332562095e+000   -1.101496412960141e+000   -1.190232162899989e+000];

    stblfrac(:,1:5,3) = ...
       [-1.354883142615948e+000   -8.855778500552980e-001   -7.773858277863260e-001   -7.357727812399337e-001   -7.181850957003714e-001;...
       -5.193811327974376e-002   -1.633949875159595e-001   -2.617724006156590e-001   -3.392619822712012e-001   -4.018554923458003e-001;...
       -6.335376612981386e-002   -1.297738965263227e-001   -1.985319371835911e-001   -2.624863717000360e-001   -3.174865471926985e-001;...
       -9.460338726038994e-002   -1.756165596280472e-001   -2.282691311262980e-001   -2.638458905915733e-001   -2.918110046315503e-001;...
       -1.158003423724520e-001   -1.620942232133271e-001   -1.790483132028017e-001   -1.937097725890709e-001   -2.109729530977958e-001;...
       -5.695213481951577e-002   -2.485009114767256e-002   -2.455774348005581e-002   -4.243720620421176e-002   -6.906960852184874e-002];
    stblfrac(:,6:10,3) = ...
       [ -7.120493514301658e-001   -7.121454153857569e-001   -7.157018373526386e-001   -7.209253714350538e-001   -7.265425280053609e-001;...
       -4.539746445467862e-001   -4.979328472153985e-001   -5.348184073267474e-001   -5.654705188376931e-001   -5.909430146259388e-001;...
       -3.637544360366539e-001   -4.030045272659678e-001   -4.369896090801292e-001   -4.671253359013797e-001   -4.944847533335236e-001;...
       -3.167744873288179e-001   -3.408290016876749e-001   -3.649204420006245e-001   -3.894754728525021e-001   -4.146904022890949e-001;...
       -2.311198638992638e-001   -2.537077422985343e-001   -2.783252370301364e-001   -3.047045003309861e-001   -3.327092628454751e-001;...
       -1.000745485866474e-001   -1.334091111747126e-001   -1.681287272131953e-001   -2.038409527302062e-001   -2.404547731975402e-001];
    stblfrac(:,11:15,3) = ...
       [-7.317075569303094e-001   -7.359762286696208e-001   -7.392122467978279e-001   -7.414607677550720e-001   -7.428480570989012e-001;...
       -6.123665499489599e-001   -6.307488506465194e-001   -6.469130897780404e-001   -6.615145568123281e-001   -6.750798357120451e-001;...
       -5.198770070249209e-001   -5.439265161390062e-001   -5.671356857543234e-001   -5.899325077218274e-001   -6.127077038151078e-001;...
       -4.406707089221509e-001   -4.675033009839270e-001   -4.952960990683358e-001   -5.242037261193876e-001   -5.544463409264927e-001;...
       -3.623063449447594e-001   -3.935470145089454e-001   -4.265595391976379e-001   -4.615525703717921e-001   -4.988293297210071e-001;...
       -2.780623638274261e-001   -3.168837529800063e-001   -3.572466721186688e-001   -3.995862986780706e-001   -4.444626893956575e-001];
    stblfrac(:,16:20,3) = ...
      [-7.435216571211187e-001   -7.436225251216279e-001   -7.432733099840527e-001   -7.425762029730668e-001   -7.416143171871161e-001;...
       -6.880470899358724e-001   -7.008026232247697e-001   -7.137148222421971e-001   -7.271697520465581e-001   -7.416143171871161e-001;...
       -6.358474023877762e-001   -6.597648782206755e-001   -6.849381555866478e-001   -7.119602076523737e-001   -7.416143171871161e-001;...
       -5.863313160876512e-001   -6.202819599064874e-001   -6.568811178840162e-001   -6.969403639254603e-001   -7.416143171871159e-001;...
       -5.388134824040952e-001   -5.820906647738434e-001   -6.294732446564461e-001   -6.821024214831549e-001   -7.416143171871159e-001;...
       -4.925935308416445e-001   -5.449092276644302e-001   -6.026377433551201e-001   -6.674379829825384e-001   -7.416143171871159e-001];

    stblfrac(:,1:5,4) = ...
       [-4.719005698760254e-003   -5.039419714218448e-002   -1.108600074872916e-001   -1.646393852283324e-001   -2.088895889525075e-001;...
       -3.167687806490741e-002   -6.488347295237770e-002   -9.913854730442322e-002   -1.306663969875579e-001   -1.574578108363950e-001;...
       -6.256908981229170e-002   -1.058190431028687e-001   -1.215669874255146e-001   -1.261149689648148e-001   -1.284283108027729e-001;...
       -7.132464704948761e-002   -5.885471032381771e-002   -3.846810486653290e-002   -2.801768649688129e-002   -2.615407079824540e-002;...
        1.186775035989228e-001    1.847231744541209e-001    1.899666578065291e-001    1.756596652192159e-001    1.538218851318199e-001;...
        1.359937191266603e+000    7.928324704017256e-001    6.068350758065271e-001    4.949176895753282e-001    4.117787224185477e-001];
    stblfrac(:,6:10,4) = ...
       [-2.445873831127209e-001   -2.729819770922066e-001   -2.951510874462016e-001   -3.121233685073350e-001   -3.249196962329062e-001;...
       -1.797875581290475e-001   -1.986122400020671e-001   -2.148458045681510e-001   -2.292024720743768e-001   -2.422125650878785e-001;...
       -1.318108373643454e-001   -1.372885008966837e-001   -1.450218673440198e-001   -1.548461140242879e-001   -1.664940537646226e-001;...
       -3.037902421859952e-002   -3.894619676380785e-002   -5.076849313651704e-002   -6.518223105549245e-002   -8.178056142331483e-002;...
        1.287679439328719e-001    1.022243387982872e-001    7.488543991005173e-002    4.698265181928261e-002    1.852002327642577e-002;...
        3.435869264264112e-001    2.844376471729288e-001    2.312306852681522e-001    1.820841981890349e-001    1.357181057787019e-001];
    stblfrac(:,11:15,4) = ...
       [-3.344714240325961e-001   -3.415532212363377e-001   -3.467713617249639e-001   -3.505859000173167e-001   -3.533413466958321e-001;...
       -2.542699931601989e-001   -2.656748454748664e-001   -2.766656461455947e-001   -2.874428940341864e-001   -2.981872822548070e-001;...
       -1.796994139325742e-001   -1.942454974557965e-001   -2.099854734361004e-001   -2.268483937252861e-001   -2.448403779828917e-001;...
       -1.003134231215546e-001   -1.206343411798188e-001   -1.426762955132322e-001   -1.664453845103147e-001   -1.920257997377931e-001;...
       -1.062008675791458e-002   -4.062891141128176e-002   -7.175196683590498e-002   -1.042870733773311e-001   -1.385948877988075e-001;...
        9.117291945474759e-002    4.766184332000264e-002    4.481886485253039e-003   -3.904933750228177e-002   -8.364689014849616e-002];
    stblfrac(:,16:20,4) = ...
       [-3.552947623689004e-001   -3.566384591258251e-001   -3.575167387322836e-001   -3.580387843935552e-001   -3.582869092425832e-001;...
       -3.090746307371333e-001   -3.202900038682522e-001   -3.320450798333745e-001   -3.445973947956370e-001   -3.582869092425832e-001;...
       -2.640470286750166e-001   -2.846415660837839e-001   -3.069024734642628e-001   -3.312464672828315e-001   -3.582869092425832e-001;...
       -2.195942670864279e-001   -2.494428999135824e-001   -2.820166786810741e-001   -3.179740384308457e-001   -3.582869092425832e-001;...
       -1.751227987938045e-001   -2.144432379167035e-001   -2.573138196343415e-001   -3.047716553689650e-001   -3.582869092425832e-001;...
       -1.301133939768983e-001   -1.794049920724848e-001   -2.327202766583559e-001   -2.916310469293936e-001   -3.582869092425832e-001];

    stblfrac(:,1:5,5) = ...
      [                      0                         0                         0                         0                         0;...
       -2.998229841415443e-002   -3.235136568035350e-002   -1.058934315424071e-002    1.472786013654386e-002    3.649529125352272e-002;...
       -4.911181618214269e-004    7.928758678692660e-002    1.295711243349632e-001    1.575625247967377e-001    1.726794061650541e-001;...
        6.444732609572413e-001    5.412205715497974e-001    4.864603927210872e-001    4.457073928551408e-001    4.118964225372133e-001;...
        4.884639795042095e+000    1.686842470765597e+000    1.132342494635284e+000    8.944978064032267e-001    7.538011200000044e-001;...
        2.410567057697245e+001    4.005534670805399e+000    2.144263118197206e+000    1.518214626927320e+000    1.198109338317733e+000];
    stblfrac(:,6:10,5) = ...
     [                      0                         0                         0                         0                         0;...
        5.320761222262883e-002    6.497369053185199e-002    7.235439352353751e-002    7.603800885095309e-002    7.671459793802817e-002;...
        1.799982238321182e-001    1.821699713013862e-001    1.806145618464317e-001    1.761248753943454e-001    1.691770293512301e-001;...
        3.823074983529713e-001    3.554905959697276e-001    3.305043126978712e-001    3.066571802106021e-001    2.834017043112906e-001;...
        6.558265419066330e-001    5.806408912949470e-001    5.191065509143589e-001    4.663489244354866e-001    4.194539705064985e-001;...
        9.966378800612080e-001    8.532685386168033e-001    7.427048697651345e-001    6.524693172360032e-001    5.756299950589361e-001];
    stblfrac(:,11:15,5) = ...
      [                      0                         0                         0                         0                         0;...
        7.500001602159387e-002    7.139599669434762e-002    6.628276247821394e-002    5.992932695316782e-002    5.250925428603021e-002;...
        1.600901411017374e-001    1.491003610537801e-001    1.363865273697878e-001    1.220722641614886e-001    1.062191001109524e-001;...
        2.602853501366307e-001    2.369238065872132e-001    2.129824521942899e-001    1.881563959610275e-001    1.621474808586950e-001;...
        3.765099860312678e-001    3.361566147323812e-001    2.973499640484341e-001    2.592283952427927e-001    2.210255604589869e-001;...
        5.079606300067100e-001    4.466711396792393e-001    3.897746494263863e-001    3.357416130711989e-001    2.832892169418335e-001];
    stblfrac(:,16:20,5) = ...
      [                      0                         0                         0                         0                         0;...
        4.411421669339249e-002    3.476266163507976e-002    2.439917920106283e-002    1.289010976694223e-002                         0;...
        8.881586460416716e-002    6.976629777350905e-002    4.886974404989612e-002    2.578932638717129e-002                         0;...
        1.346349888095220e-001    1.052403813710735e-001    7.348119932151805e-002    3.870673240105876e-002                         0;...
        1.820030836908522e-001    1.413881485626739e-001    9.829989964989198e-002    5.165115573609639e-002                         0;...
        2.312355801087936e-001    1.783807793433976e-001    1.233869208812706e-001    6.463145748462040e-002    9.714451465470120e-017];


    stblfrac(:,1:5,6) = ...
       [ 4.719005698760275e-003    5.039419714218456e-002    1.108600074872919e-001    1.646393852283322e-001    2.088895889525074e-001;...
        1.944613194060750e-001    3.117984496788369e-001    3.615078716560812e-001    3.879646155737581e-001    4.042606354602197e-001;...
        3.045958300133999e+000    1.315675725057089e+000    9.757973307352019e-001    8.294361410388060e-001    7.456405896421690e-001;...
        2.339312510820383e+001    3.858569195402605e+000    2.091507439545032e+000    1.515362821077606e+000    1.231804842218289e+000;...
        1.231812404655975e+002    9.151933726881032e+000    3.856468345925451e+000    2.470027172456050e+000    1.862167039303084e+000;...
        5.049829135345403e+002    1.890722475322573e+001    6.427275565975617e+000    3.715903402980179e+000    2.636417882085815e+000];
    stblfrac(:,6:10,6) = ...
       [ 2.445873831127209e-001    2.729819770922065e-001    2.951510874462016e-001    3.121233685073347e-001    3.249196962329060e-001;...
        4.152379986226543e-001    4.229018705591941e-001    4.280900470005300e-001    4.311273812611276e-001    4.321442286112657e-001;...
        6.900226415397631e-001    6.495436520935480e-001    6.180526887451320e-001    5.921654464012007e-001    5.697923159645174e-001;...
        1.060749495885882e+000    9.442937075476816e-001    8.583603822642385e-001    7.911221543980916e-001    7.360251815557063e-001;...
        1.521067254392224e+000    1.300039377551776e+000    1.142711537858461e+000    1.023045102736937e+000    9.273664178094935e-001;...
        2.065989355542487e+000    1.711228437455139e+000    1.466088158475343e+000    1.283765226486882e+000    1.140575450959062e+000];
    stblfrac(:,11:15,6) = ...
        [3.344714240325963e-001    3.415532212363379e-001    3.467713617249641e-001    3.505859000173170e-001    3.533413466958320e-001;...
        4.312423594533669e-001    4.285591238013830e-001    4.242644840754073e-001    4.185310514289916e-001    4.115050794489342e-001;...
        5.495326577846258e-001    5.304020801294532e-001    5.116943409858906e-001    4.928954730588648e-001    4.736165965702772e-001;...
        6.890778676134198e-001    6.476526200515113e-001    6.099033923678876e-001    5.744600864566568e-001    5.402514096915735e-001;...
        8.477633920324498e-001    7.792812067953944e-001    7.185943530039393e-001    6.633207377171386e-001    6.116407715135426e-001;...
        1.023262411940948e+000    9.237922892835746e-001    8.369566524681974e-001    7.591595457820644e-001    6.877508180861301e-001];
    stblfrac(:,16:20,6) = ...
       [ 3.552947623689000e-001    3.566384591258254e-001    3.575167387322835e-001    3.580387843935554e-001    3.582869092425831e-001;...
        4.032875933324668e-001    3.939222836649399e-001    3.833860261287606e-001    3.715758694363207e-001    3.582869092425831e-001;...
        4.535361612745278e-001    4.323485980953122e-001    4.097162006469898e-001    3.852184728042033e-001    3.582869092425835e-001;...
        5.063904595668142e-001    4.720865286037160e-001    4.365637761840112e-001    3.989743423180101e-001    3.582869092425835e-001;...
        5.620594176198462e-001    5.132627179036522e-001    4.639774715385669e-001    4.128508865888630e-001    3.582869092425835e-001;...
        6.206265009880273e-001    5.559603894356728e-001    4.919976875425384e-001    4.268552022160075e-001    3.582869092425835e-001];

    stblfrac(:,1:5,7) = ...
       [ 1.354883142615939e+000    8.855778500552969e-001    7.773858277863266e-001    7.357727812399328e-001    7.181850957003700e-001;...
        2.264297017396562e+001    3.703766301758638e+000    2.034998948698223e+000    1.510923485095245e+000    1.265729978744353e+000;...
        1.955956459466261e+002    1.118917023817671e+001    4.357570503031440e+000    2.718083521990130e+000    2.041945502327640e+000;...
        1.131527106972301e+003    2.742019413138009e+001    8.094356141096943e+000    4.405625422851678e+000    3.045873292912599e+000;...
        4.991370610374878e+003    5.832596523112534e+001    1.361736440227531e+001    6.617793943005997e+000    4.277065691957527e+000;...
        1.808482789458792e+004    1.120299053944505e+002    2.131886896428897e+001    9.395528700779570e+000    5.735282952993835e+000];
    stblfrac(:,6:10,7) = ...
       [ 7.120493514301658e-001    7.121454153857567e-001    7.157018373526382e-001    7.209253714350531e-001    7.265425280053608e-001;...
        1.126910935459891e+000    1.039315711942880e+000    9.801156996469297e-001    9.380990288559633e-001    9.070002633955093e-001;...
        1.682687096145072e+000    1.462088170281394e+000    1.313508264506275e+000    1.206803763884095e+000    1.126395471042167e+000;...
        2.368493556832589e+000    1.968378518204384e+000    1.704951233806636e+000    1.518043793772535e+000    1.377948007790416e+000;...
        3.176211386678905e+000    2.549432728119129e+000    2.146593646702069e+000    1.865193645178458e+000    1.656315874739094e+000;...
        4.099439855675913e+000    3.198582996879541e+000    2.632582798272859e+000    2.243339709179312e+000    1.957469852365064e+000];
    stblfrac(:,11:15,7) = ...
       [ 7.317075569303093e-001    7.359762286696208e-001    7.392122467978273e-001    7.414607677550722e-001    7.428480570989009e-001;...
        8.829463516299942e-001    8.633779161543368e-001    8.465599716104961e-001    8.313215935120923e-001    8.168794983145117e-001;...
        1.063360967480519e+000    1.012144436660489e+000    9.690437805764626e-001    9.314651792280744e-001    8.975270882378618e-001;...
        1.268363069256580e+000    1.179563109954373e+000    1.105319244270462e+000    1.041384485194864e+000    9.846979577532636e-001;...
        1.493891969504980e+000    1.362797559741365e+000    1.253624580847262e+000    1.160149469096889e+000    1.078008118654219e+000;...
        1.736744887299007e+000    1.559416515511960e+000    1.412280239489399e+000    1.286729855523644e+000    1.176933895080190e+000];
    stblfrac(:,16:20,7) = ...
       [ 7.435216571211178e-001    7.436225251216276e-001    7.432733099840527e-001    7.425762029730666e-001    7.416143171871158e-001;...
        8.027015701907034e-001    7.884022863227798e-001    7.736657968963813e-001    7.581862145381915e-001    7.416143171871158e-001;...
        8.658237613571567e-001    8.352619776464638e-001    8.049334692839693e-001    7.740056420537431e-001    7.416143171871158e-001;...
        9.329399521299938e-001    8.842632875709708e-001    8.371061471443788e-001    7.900396709438159e-001    7.416143171871157e-001;...
        1.003953952010710e+000    9.354146255148074e-001    8.702022492276336e-001    8.062927602676150e-001    7.416143171871157e-001;...
        1.078670034479511e+000    9.886802003678273e-001    9.042295460529033e-001    8.227686378257326e-001    7.416143171871157e-001];

    stblfrac(:,1:5,8) = ...
        [4.738866777987514e+002    1.684460387562540e+001    5.619926961081758e+000    3.281734135829232e+000    2.397479160864624e+000;...
        4.841681688643794e+003    5.491635522391771e+001    1.256979234254407e+001    6.069209132601843e+000    3.940274296039883e+000;...
        3.154616792561625e+004    1.420805372229245e+002    2.403953052063284e+001    9.998426062380954e+000    5.930362539243756e+000;...
        1.520631636586534e+005    3.148956061770992e+002    4.132943146104890e+001    1.518515134801384e+001    8.367182529059960e+000;...
        5.901656732159231e+005    6.246491282963873e+002    6.581680474603525e+001    2.173557079848703e+001    1.125045444319795e+001;...
        1.944624278667431e+006    1.139848804168331e+003    9.894809619823921e+001    2.974824391888133e+001    1.458002371721213e+001];
    stblfrac(:,6:10,8) = ...
       [1.959508008521145e+000    1.708174380583837e+000    1.550822278332539e+000    1.447013328833976e+000    1.376381920471174e+000;...
        2.963447020215305e+000    2.423693540860402e+000    2.089182215079736e+000    1.865572849084425e+000    1.708118159360888e+000;...
        4.190132768594454e+000    3.268280841745006e+000    2.710662024401290e+000    2.341995909523891e+000    2.082469140437107e+000;...
        5.624308785058203e+000    4.226708866462347e+000    3.402197103627229e+000    2.865360079281767e+000    2.490393899977397e+000;...
        7.254212029229660e+000    5.287806421003054e+000    4.154585933912857e+000    3.428194997160839e+000    2.925780747207696e+000;...
        9.070365685373144e+000    6.442950257298201e+000    4.960971490178073e+000    4.025088868546689e+000    3.384287797654701e+000];
    stblfrac(:,11:15,8) = ...
       [ 1.327391983207241e+000    1.292811209009341e+000    1.267812588403031e+000    1.249132310044230e+000    1.234616432819130e+000;...
        1.593041126030172e+000    1.506471132927683e+000    1.439628954887186e+000    1.386580264484466e+000    1.343153406231364e+000;...
        1.891158929781140e+000    1.745070641877115e+000    1.630251730907927e+000    1.537630629971792e+000    1.460938380853296e+000;...
        2.214464603850502e+000    2.003098342270666e+000    1.835905829230373e+000    1.700021765831942e+000    1.586823477367793e+000;...
        2.557944985263177e+000    2.276562749626175e+000    2.053593165082403e+000    1.871725504345519e+000    1.719630879614922e+000;...
        2.918103805585008e+000    2.562588803694463e+000    2.281050180010934e+000    2.051085944176459e+000    1.858294826115218e+000];
    stblfrac(:,16:20,8) = ...
       [ 1.222879780072204e+000    1.213041554808854e+000    1.204541064608597e+000    1.197016952370690e+000    1.190232162899990e+000;...
        1.306371038922589e+000    1.274091491606534e+000    1.244744203398707e+000    1.217124809801410e+000    1.190232162899990e+000;...
        1.395630981221581e+000    1.338301797693731e+000    1.286320343916442e+000    1.237570697847646e+000    1.190232162899990e+000;...
        1.490188322141933e+000    1.405530485165501e+000    1.329245194088195e+000    1.258353899045780e+000    1.190232162899990e+000;...
        1.589489775546923e+000    1.475587597649461e+000    1.373481210080780e+000    1.279472666002594e+000    1.190232162899990e+000;...
        1.692973560150181e+000    1.548256386823049e+000    1.418980226656540e+000    1.300924242481222e+000    1.190232162899990e+000];

    stblfrac(:,1:5,9) = ...
        [1.890857122067037e+006    1.074884919696010e+003    9.039223076384690e+001    2.645987890965103e+001    1.274134564492299e+001;...
        1.434546473316804e+007    2.987011338973518e+003    1.804473474220022e+002    4.487048929338575e+001    1.960113433547389e+001;...
        7.716266115204613e+007    6.969521346220721e+003    3.196657990381036e+002    6.941784107578008e+001    2.798990029407097e+001;...
        3.253192550565641e+008    1.437315176424486e+004    5.205876769957880e+002    1.006582035946658e+002    3.790739646062081e+001;...
        1.143638705833100e+009    2.703823367877713e+004    7.964291266167923e+002    1.391051003571698e+002    4.935349274736288e+001;...
        3.492208269966229e+009    4.737075925045248e+004    1.161019167208514e+003    1.852377745522907e+002    6.232811767701676e+001];
    stblfrac(:,6:10,9) = ...
        [7.864009406553027e+000    5.591791397752693e+000    4.343949435866960e+000    3.580521076832391e+000    3.077683537175252e+000;...
        1.132727408868559e+001    7.671280872680232e+000    5.732691330034323e+000    4.573075545294608e+000    3.818589092027862e+000;...
        1.533578393202605e+001    9.991349773961725e+000    7.243609507849516e+000    5.634462725204553e+000    4.601857009791827e+000;...
        1.985701175129152e+001    1.252691966593449e+001    8.859346059355138e+000    6.752431092162364e+000    5.418366793527828e+000;...
        2.486500490402286e+001    1.525895955988075e+001    1.056731639206889e+001    7.918478700695184e+000    6.262067266019560e+000;...
        3.033836510475647e+001    1.817240938152932e+001    1.235792736188858e+001    9.126360342186048e+000    7.128676006881803e+000];
    stblfrac(:,11:15,9) = ...
        [2.729262880847459e+000    2.479627528870858e+000    2.297138304998906e+000    2.162196365947915e+000    2.061462692277420e+000;...
        3.297130126832188e+000    2.920640582387343e+000    2.640274592919582e+000    2.426998377788287e+000    2.262233765245289e+000;...
        3.893417077901593e+000    3.382471282597797e+000    2.999860062957988e+000    2.705234908082859e+000    2.473610569743775e+000;...
        4.510891038980249e+000    3.859051363710381e+000    3.370702720510665e+000    2.992693808833481e+000    2.692636527934335e+000;...
        5.144949915764652e+000    4.346635348399592e+000    3.749599176843221e+000    3.286641675099088e+000    2.917178603817272e+000;...
        5.792462636377325e+000    4.842756648977701e+000    4.134472567050430e+000    3.585273662390985e+000    3.145733197974777e+000];
    stblfrac(:,16:20,9) = ...
        [1.985261982958638e+000    1.926542865732524e+000    1.880296841910385e+000    1.843044812063057e+000    1.812387604873647e+000;...
        2.133064562958712e+000    2.029912595114798e+000    1.945516531961286e+000    1.874392545595589e+000    1.812387604873647e+000;...
        2.288441176274372e+000    2.137883347336651e+000    2.012884307837858e+000    1.906295529437326e+000    1.812387604873647e+000;...
        2.449737610939970e+000    2.249772716121334e+000    2.082221357100924e+000    1.938735806854783e+000    1.812387604873647e+000;...
        2.615585030563546e+000    2.364937633815368e+000    2.153342270485199e+000    1.971693892149562e+000    1.812387604873647e+000;...
        2.784907129216124e+000    2.482804054400846e+000    2.226062706102394e+000    2.005149380181030e+000    1.812387604873647e+000];

    %%%% Interpolate to find initial guess
    [alpIn betIn uIn] = meshgrid(alpha,beta,utemp(middle));
    X0(middle) = interp3(Alp,Bet,P,stblfrac,alpIn, betIn, uIn, 'linear');

end

X0 = reshape(X0,size(u));

end





