function x = DoublePareto(n,alpha,varargin)
% This function generates Double Pareto random variables with sample size n 
% and parameter alpha

   
if nargin<3
    x1 = (1-rand(n,1)).^(-1/alpha); % draws from Pareto with tail index alpha, x>1
    x2 = (1-rand(n,1)).^(-1/alpha);
    x= x1-x2; % draws from double-Pareto with tail index alpha
else
    x1 = (1-rand(n,1)).^(-1/alpha);
    x2 = (1-rand(n,1)).^(-1/varargin{1});
    x=x1-x2;
end

end