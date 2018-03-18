function p = MonteCarloAlgorithm(T,N,B,alpha,beta,v1,h1)
    Coverage_PB=zeros(N,1);
    parfor e=1:N
     % Generate Double Pareto random variable
%         x=DoublePareto(T,alpha)
        x=stblrnd(alpha,beta,1,0,T,1)

     % Choose the percentage of data truncated
       % v=quantile(abs(x),v1);
       X = sort(abs(x),'descend');
       v = X(floor(T*v1));

     % Create Bootstrap samples
        W=zeros(T,B);
        r=abs(x)>v;
        r1=abs(x)<=v;
        W(r,:)=1;

      % Selecting the parts where the values need to be replaced
        n1=sum(r1); 
        
      % Create Efrons bootstrap which is a Multinomial random variable 
      % with sum equal to that of W
        % W(r1,:)=binornd(1,0.5,n1,B)*2-1;
        
      % Mamen Weights 1
        p=(sqrt(5)+1)/(2*sqrt(5));
        W(r1,:)=sqrt(5)*(p-binornd(1,p,n1,B));

        
      % Mamen Weights 2
        % u=normrnd(0,1,n1,B);
        % w=normrnd(0,1,n1,B);
        % W(r1,:)=u/(sqrt(2))+0.5*(w.^2-1);

      % Normal
        % W(r1,:)=normrnd(0,1,n1,B);
      
      %Efron bootstrap
        % W(r1,:)=mnrnd(n1,ones(1,n1)*(1/n1),B)';



    % Create bootstrap observations
        Xboot=repmat(x,1,B).*W;

    % Compute the t statistics of the bootstrap observations as well as the
    % Original observations of Adriana
        T1=(T^0.5)*mean(Xboot)./std(Xboot);
        Tt=(T^0.5)*mean(x)./std(x);
        
        % Confidence Interval
        k=[quantile(T1,(1+h1)/2) quantile(T1,(1-h1)/2)];
        CI_PB=mean(x)-std(x)*k/(T^0.5);

        % r=mean(Xboot);
        % k=[quantile(r,(1+h1)/2) quantile(r,(1-h1)/2)];
        % CI_PB=mean(x)-k;

        % how many times does theta =0 belong to the interval 
        if (CI_PB(1)<0)&&(CI_PB(2)>0)
            Coverage_PB(e)=1
        end
    end
    p=mean(Coverage_PB);
end