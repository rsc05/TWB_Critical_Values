% t = num2cell([50,1000,400,0.3,0.6,1,0,0,0.03,0.95]);
% [T,N,B,alpha,beta,scale,orgmean,testedmean,v1,h1]=deal(t{:});

T=1000;
N=1000; % Monte Carlo Replications
B=400; %Bootstrap samples
alpha=1.3;
beta=0.5
h1=0.95;

tic
ii=0.5:0.02:0.98;
p1=zeros(length(ii),1);

parfor i=1:length(ii)
    v1=ii(i);
    p=MonteCarloAlgorithm(T,N,B,alpha,beta,v1,h1);
    p1(i)=p;
end

figure(1)
hold on;
plot(ii,p1,'b')
toc

[c index] = min(abs(p1-h1));
v1=ii(index)
p1(index)

alpha=0.5
beta=0.7
ii=0.5:0.02:1;
p1=zeros(length(ii),1);

parfor i=1:length(ii)
    v1=ii(i);
    p=MonteCarloAlgorithm(T,N,B,alpha,beta,v1,h1);
    p1(i)=p;
end


figure(1)
hold on;
plot(ii,p1,'b')
toc

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
tic
T=1000;
N=1000; % Monte Carlo Replications
B=400; %Bootstrap samples
h1=0.95;
alpha=0.5
GG=[];
for beta1=0.1:0.1:1
    beta=beta1;
    

% Try to find the best v1 such that the probability p is higest as well as
% close to h1

    % Compute p for the v1 10 diggit below maximum of y vc1


    ii=0.8:0.02:1;
    p1=zeros(length(ii),1);
    parfor i=1:length(ii)
	    v1=ii(i);
	    p=MonteCarloAlgorithm(T,N,B,alpha,beta,v1,h1);
	    p1(i)=p;
	end

    plot(ii,p1)
    hold on
    % Find the largest p1 close to the 95
    [c index] = min(abs(p1-h1));
    v1=ii(index) ;

    GG=[GG; p1(index) v1 alpha beta];
end
toc