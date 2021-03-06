function w = TheModeQuantofV1(alpha1,beta1)


    alpha=0.1:0.1:2;
    beta=0:0.1:1;

% V1=[  0         0   -0.0001   -0.0001         0         0         0         0         0         0         0
%    -0.0585   -0.6806   -0.3482   -0.2287   -0.1629   -0.1190   -0.0864   -0.0601   -0.0379   -0.0181   -0.0000
%    -0.1154   -1.3601   -0.6955   -0.4568   -0.3255   -0.2379   -0.1725   -0.1201   -0.0757   -0.0364   -0.0000
%    -0.1694   -2.0372   -1.0414   -0.6839   -0.4874   -0.3563   -0.2586   -0.1801   -0.1136   -0.0545   -0.0000
%    -0.2197   -2.7116   -1.3852   -0.9094   -0.6484   -0.4741   -0.3442   -0.2399   -0.1514   -0.0728   -0.0000
%    -0.2658   -3.3826   -1.7262   -1.1332   -0.8080   -0.5913   -0.4296   -0.2996   -0.1891   -0.0909   -0.0000
%    -0.3074   -4.0499   -2.0645   -1.3550   -0.9663   -0.7075   -0.5143   -0.3589   -0.2268   -0.1090   -0.0000
%    -0.3444   -4.7133   -2.3998   -1.5743   -1.1231   -0.8227   -0.5986   -0.4181   -0.2642   -0.1272   -0.0000
%    -0.3770   -5.3729   -2.7318   -1.7914   -1.2781   -0.9369   -0.6822   -0.4769   -0.3017   -0.1453   -0.0000
%    -0.4053   -6.0288   -3.0608   -2.0059   -1.4313   -1.0498   -0.7652   -0.5355   -0.3391   -0.1634   -0.0000
%    -0.4293   -6.6810   -3.3868   -2.2181   -1.5828   -1.1616   -0.8474   -0.5937   -0.3764   -0.1816   -0.0000];;

k1=[ 0         0         0         0         0         0         0         0    0.0001         0         0   -0.0001   -0.0001
    0.0000   -0.0000    0.0005    0.0050    0.0205    0.0536    0.1142    0.2317    0.5637   -0.0585   -0.6806   -0.3482   -0.2287
   -0.0000   -0.0000    0.0010    0.0108    0.0430    0.1100    0.2310    0.4659    1.1294   -0.1154   -1.3601   -0.6955   -0.4568
    0.0000    0.0001    0.0018    0.0180    0.0683    0.1703    0.3524    0.7043    1.6986   -0.1694   -2.0372   -1.0414   -0.6839
    0.0001    0.0001    0.0028    0.0264    0.0966    0.2351    0.4787    0.9477    2.2724   -0.2197   -2.7116   -1.3852   -0.9094
   -0.0000    0.0001    0.0042    0.0364    0.1281    0.3043    0.6104    1.1964    2.8512   -0.2658   -3.3826   -1.7262   -1.1332
    0.0000    0.0001    0.0058    0.0479    0.1627    0.3780    0.7473    1.4505    3.4350   -0.3074   -4.0499   -2.0645   -1.3550
    0.0001    0.0001    0.0079    0.0611    0.2005    0.4563    0.8893    1.7100    4.0238   -0.3444   -4.7133   -2.3998   -1.5743
    0.0000    0.0001    0.0103    0.0758    0.2416    0.5389    1.0364    1.9746    4.6177   -0.3770   -5.3729   -2.7318   -1.7914
    0.0000    0.0002    0.0132    0.0924    0.2859    0.6257    1.1882    2.2442    5.2163   -0.4053   -6.0288   -3.0608   -2.0059
    0.0001    2.4778*10^(-4)    0.0165    0.1106    0.3333    0.7169    1.3449    2.5187    5.8196   -0.4293   -6.6810   -3.3868   -2.2181];
k2=[ 0         0         0         0         0         0         0
   -0.1629   -0.1190   -0.0864   -0.0601   -0.0379   -0.0181   -0.0000
   -0.3255   -0.2379   -0.1725   -0.1201   -0.0757   -0.0364   -0.0000
   -0.4874   -0.3563   -0.2586   -0.1801   -0.1136   -0.0545   -0.0000
   -0.6484   -0.4741   -0.3442   -0.2399   -0.1514   -0.0728   -0.0000
   -0.8080   -0.5913   -0.4296   -0.2996   -0.1891   -0.0909   -0.0000
   -0.9663   -0.7075   -0.5143   -0.3589   -0.2268   -0.1090   -0.0000
   -1.1231   -0.8227   -0.5986   -0.4181   -0.2642   -0.1272   -0.0000
   -1.2781   -0.9369   -0.6822   -0.4769   -0.3017   -0.1453   -0.0000
   -1.4313   -1.0498   -0.7652   -0.5355   -0.3391   -0.1634   -0.0000
   -1.5828   -1.1616   -0.8474   -0.5937   -0.3764   -0.1816   -0.0000];

V1=[k1 k2];

 
%     A=[A(:,1) A];
    w = interp2(alpha,beta,V1,alpha1,beta1);
    
end