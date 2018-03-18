tic
T=50;
N=1000; % Monte Carlo Replications
B=400; %Bootstrap samples
h1=0.95;
alpha=1.1
GG=[];
for beta1=0.1:0.1:1
    beta=beta1;
    mode1=TheModeQuantofV1(alpha,beta);    

% Try to find the best v1 such that the probability p is higest as well as
% close to h1

    % Compute p for the v1 10 diggit below maximum of y vc1


    ii=0.8:0.02:1;
    p1=zeros(length(ii),1);
    parfor i=1:length(ii)
      v1=ii(i);
      p=MonteCarloAlgorithm1(T,N,B,alpha,beta,mode1,v1,h1);
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

GG

leg1=legend({'$\beta_1$';'$\beta_2$';'$\beta_3$';'$\beta_4$';'$\beta_5$';'$\beta_6$';'$\beta_7$';'$\beta_8$';'$\beta_9$';'$\beta_{10}$'})
set(leg1,'Location','northeastoutside','Interpreter','latex','FontSize',17);
