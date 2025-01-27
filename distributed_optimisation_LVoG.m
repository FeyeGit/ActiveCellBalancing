clear; close all; clc;
%% Duality approach, using CPLEX solver
%% Load models and drive cycle
load Profile_adapted_2
load SS_LPV
load RC_1st_ARX_smooth_4
load curve_t2_smooth
load variations

%% make smooth
A.Method = 'spline';
B.Method = 'spline';
D.Method = 'spline';
% EMF.Method = 'spline';

load old_parameters
A = A_old; B = B_old; D = D_old; 

%% Faulty parameters
% load Profile_adapted_2
% load SS_LPV
% load RC_1st_ARX_smooth_4
% load curve_t2_smooth
% load variations
% load old_parameters
% A = A_old; B = B_old; D = D_old; 
% 
% %% Edit the A matrix
% GridVectors = A.GridVectors{1,1};
% GridVectors = [GridVectors(1:2) GridVectors(5:end)];
% GridVectors = [GridVectors(1:7) 1];
% Values = [A.Values(1:2) A.Values(5:end)];
% Values = [Values(1:7) 0.9812];
% Anew = griddedInterpolant(GridVectors,Values);
% Anew.ExtrapolationMethod = 'nearest';
% 
% figure;plot([0:0.001:1],A([0:0.001:1]));hold on;
% plot([0:0.001:1],Anew([0:0.001:1]),'r')
% A=Anew;
% 
% Anew = griddedInterpolant([0 0.05 0.09 A.GridVectors{1,1}],[0.75 0.78 0.8 A.Values]);
% A=Anew;
% Bnew = griddedInterpolant([0 0.05 0.09 B.GridVectors{1,1}],[30e-3 20e-3 10e-3 B.Values]);
% B=Bnew;
% Dnew = griddedInterpolant([0 0.05 0.09 D.GridVectors{1,1}],[0.031 0.028 0.025 D.Values]);
% D=Dnew;

figure;
plot([0:0.001:1],A([0:0.001:1]),'r')
figure;
plot([0:0.001:1],B([0:0.001:1]),'r')
figure;
plot([0:0.001:1],D([0:0.001:1]),'r')
figure;
plot([0:0.001:1],EMF([0:0.001:1]),'r')

%% Scale capacity
C0 = C0/10;

%% Define scenario
N = 3;                             % number of cells
P = P(1000:end);
P = P*N;                            % scale power cycle          
bal_lim = 0.5;
Rb = 0.5;
prefix = -100;                      % prepended discharge power 
y_low = 2.6;

%% Optimisation parameters
gamma_lambda = 1;
gamma_mu = 1;
gamma_nu = 1;
maxIter = 3000;

%% fmincon settings
options_fmincon = optimset('fmincon');
options_fmincon.Display = 'off'; 
options_fmincon.FunctionTolerance = 1.e-8;
options_fmincon.ConstraintTolerance = 1.e-8;

%% Plotting colors
green = [12 195 82] ./ 255;
darkblue = [1 17 181] ./ 255;
red = [255 0 0]./255;
color = [darkblue;red;green];

%% Establish baseline
x0 = [0.15;0];
x = x0;
x = repmat(x,N,1);
As = [];
Bs = [];

P(20:40) = -65;

P(41:50) = 200;

for k = 1:length(P)
    for n = 1:N
        As(2*n-1:2*n,2*n-1:2*n) = [1 0; 0 A(x(2*n-1,k))^AB_var(n)];
        Bs(2*n-1:2*n,1:n+1) = [1/(C0*C0_var(n)) zeros(1,n-1) 1/(C0*C0_var(n));B(x(2*n-1,k))*AB_var(n) zeros(1,n-1) B(x(2*n-1,k))*AB_var(n)];
        R0(n) = D(x(2*n-1,k))*D_var(n);
        Vemf(n) = EMF(x(2*n-1,k));
    end
     
    a = sum(R0);
    b = sum(Vemf)+repmat([0 1],1,N)*x(:,k);
    c = -P(k);
    w(k) = (-b + sqrt(b^2-4*a*c))/(2*a);
     
    U_bal(:,k) = zeros(N,1);
    U = [w(k); U_bal(:,k)];
     
    x(:,k+1) = As*x(:,k) + Bs*U;
    for n=1:N
        y(n,k) = x(2*n,k) + [R0(n) zeros(1,n-1) R0(n) zeros(1,N-n)]*(U) + Vemf(n);
    end
    if max(y(:,k)<2.6)
        ending = k-1;
        break
    else
        ending = k;
    end
end

P_original = P(1:ending);

% plot results
figure;hold on;
for n=1:N
   plot(y(n,1:end)) 
end

figure;hold on;
for n=1:N
   plot(x(2*n-1,1:end)) 
end

%% Initialisation for unknown starting point
% k0 = 500;
% % 
% P_saved = P_original;
% P_test = [prefix*ones(1,k0) P_saved(1:ending)];
% feasible = k0;
% infeasible = 100;
% 
% while infeasible+1~=feasible
%     y_low_violated = 0;
%     start = ceil(infeasible+(feasible-infeasible)/2);
%     P = P_test(start:end);
% 
%     % Initial condition
%     x = x0;
%     x = repmat(x,N,1);
%     As = [];
%     Bs = [];
% 
%     % System definition
%     C_avg = mean(C0*C0_var);
% 
%     for k = 1:length(P)
%         for n = 1:N
%             As(2*n-1:2*n,2*n-1:2*n) = [1 0; 0 A(x(2*n-1,k))^AB_var(n)];
%             Bs(2*n-1:2*n,1:n+1) = [1/(C0*C0_var(n)) zeros(1,n-1) 1/(C0*C0_var(n));B(x(2*n-1,k))*AB_var(n) zeros(1,n-1) B(x(2*n-1,k))*AB_var(n)];
%             R0(n) = D(x(2*n-1,k))*D_var(n);
%             Vemf(n) = EMF(x(2*n-1,k));
%         end
% 
%         a = sum(R0);
%         b = sum(Vemf)+repmat([0 1],1,N)*x(:,k);
%         c = -P(k);
%         w(k) = (-b + sqrt(b^2-4*a*c))/(2*a);
% 
%         if k == 1
%             U_bal(:,k) = zeros(N,1);
%         elseif k > 1
%             for n=1:N
%                 C_left(n,k) = (x(2*n-1,k)-0.15)*C0*C0_var(n);
%             end
%             if max(abs(C_left(:,k)))-mean(C_left(:,k))>1
%                 lb = w(k)-3*bal_lim;
%                 ub = w(k)+3*bal_lim;
%                 H_cons_1 = zeros(N+1,N+1);
%                 H_cons_1(1,1) = 2*a;
%                 k_cons_1 = zeros(N+1,1);
%                 k_cons_1(1,1) = b;
%                 d_cons_1 = -P(k);
%                 H_cons_2 = zeros(N+1,N+1);
%                 k_cons_2 = zeros(N+1,1);
%                 d_cons_2 = 0;
% 
%                 for n=2:N+1
%                     if C_left(n-1,k)>mean(C_left(:,k))
%                         lb(n) = -bal_lim;
%                         ub(n) = 0;
%                     else
%                         lb(n) = 0;
%                         ub(n) = bal_lim;
%                     end
%                     H_cons_1(1,n) = R0(n-1);
%                     H_cons_1(n,1) = R0(n-1);
%                     if n>1
%                         H_cons_2(1,n) = R0(n-1);
%                         H_cons_2(n,1) = R0(n-1);
%                         H_cons_2(n,n) = 2*(R0(n-1)+Rb);
%                         k_cons_2(n,1) = Vemf(n-1)+x(2*(n-1),k);
%                     end
%                 end
% 
%                 u0 = zeros(N+1,1);
%                 u0(1,1) = w(k);
%                 nonlconstr = @(x)quadconstr(x,H_cons_1,k_cons_1,d_cons_1,H_cons_2,k_cons_2,d_cons_2);
%                 x_opt = fmincon(@(x_opt) I_complete_par_simplified_forward(x_opt,C0*C0_var,x(:,k),N),...
%                     u0,[],[],[],[],lb,ub,nonlconstr,options_fmincon);
%                 w(k) = x_opt(1); U_bal(:,k) = x_opt(2:end);
%             else
%                 U_bal(:,k) = zeros(N,1);
%             end 
%         end 
% 
%         U = [w(k); U_bal(:,k)];
% 
%         x(:,k+1) = As*x(:,k) + Bs*U;
%         for n=1:N
%             y(n,k) = x(2*n,k) + [R0(n) zeros(1,n-1) R0(n) zeros(1,N-n)]*(U) + Vemf(n);
%         end
%         if max(y(:,k)<2.6)
%             ending_search = k;
%             y_low_violated = 1;
%             break
%         else
%             ending_search = k;
%         end
%     end
%     
%     if (P_original(ending)==P(ending_search) && y_low_violated == 0)
%         feasible = start;
%     else
%         infeasible = start;
%     end
%     feasible
%     infeasible
% end
% 
% figure;hold on;
% for n=1:N
%    plot(y(n,1:ending_search)) 
% end
% 
% figure;hold on;
% for n=1:N
%    plot(x(2*n-1,1:ending_search)) 
% end
% 
% figure;hold on;
% for n=1:N
%    plot(C_left(n,1:ending_search)) 
% end
% 
% figure;hold on;
% for n=1:N
%    plot(U_bal(n,1:ending_search)) 
% end
% legend
% 
% pause
%% Initialise feasibility check
start = 500; % horizon when starting at 0.3 s
% start = 404; % horizon when starting at 1 s
% start = 464; % start P=600 for smooth nonedited LPV
% start = 477; %start P=600 for smooth edited LPV

%% Initialisation for unknown starting point
clear x y w U_bal
k0 = 500;
P_saved = P_original;
P_test = [0.6*prefix*ones(1,k0) P_saved(1:ending)];
P = P_test(start:end);

% Initial condition
x = x0;
x = repmat(x,N,1);
As = [];
Bs = [];

P = [P -75];

% System definition
C_avg = mean(C0*C0_var);
y_low_violated = 0;

for k = 1:length(P)
%     disp(k)
    for n = 1:N
        As(2*n-1:2*n,2*n-1:2*n) = [1 0; 0 A(x(2*n-1,k))^AB_var(n)];
        Bs(2*n-1:2*n,1:n+1) = [1/(C0*C0_var(n)) zeros(1,n-1) 1/(C0*C0_var(n));B(x(2*n-1,k))*AB_var(n) zeros(1,n-1) B(x(2*n-1,k))*AB_var(n)];
        R0(n) = D(x(2*n-1,k))*D_var(n);
        Vemf(n) = EMF(x(2*n-1,k));
    end

    a = sum(R0);
    b = sum(Vemf)+repmat([0 1],1,N)*x(:,k);
    c = -P(k);
    w(k) = (-b + sqrt(b^2-4*a*c))/(2*a);

    if k == 1
        U_bal(:,k) = zeros(N,1);
    elseif k > 1
        for n=1:N
            C_left(n,k) = (x(2*n-1,k)-0.08)*C0*C0_var(n);
        end
        if max(abs(C_left(:,k)))-mean(C_left(:,k))>1
            lb = w(k)-3*bal_lim;
            ub = w(k)+3*bal_lim;
            H_cons_1 = zeros(N+1,N+1);
            H_cons_1(1,1) = 2*a;
            k_cons_1 = zeros(N+1,1);
            k_cons_1(1,1) = b;
            d_cons_1 = -P(k);
            H_cons_2 = zeros(N+1,N+1);
            k_cons_2 = zeros(N+1,1);
            d_cons_2 = 0;

            for n=2:N+1
                if C_left(n-1,k)>mean(C_left(:,k))
                    lb(n) = -bal_lim;
                    ub(n) = 0;
                else
                    lb(n) = 0;
                    ub(n) = bal_lim;
                end
                H_cons_1(1,n) = R0(n-1);
                H_cons_1(n,1) = R0(n-1);
                if n>1
                    H_cons_2(1,n) = R0(n-1);
                    H_cons_2(n,1) = R0(n-1);
                    H_cons_2(n,n) = 2*(R0(n-1)+Rb);
                    k_cons_2(n,1) = Vemf(n-1)+x(2*(n-1),k);
                end
            end

            u0 = zeros(N+1,1);
            u0(1,1) = w(k);
            nonlconstr = @(x)quadconstr(x,H_cons_1,k_cons_1,d_cons_1,H_cons_2,k_cons_2,d_cons_2);
            x_opt = fmincon(@(x_opt) I_complete_par_simplified_forward(x_opt,C0*C0_var,x(:,k),N),...
                u0,[],[],[],[],lb,ub,nonlconstr,options_fmincon);
            w(k) = x_opt(1); U_bal(:,k) = x_opt(2:end);
        else
            U_bal(:,k) = zeros(N,1);
        end 
    end 

    U = [w(k); U_bal(:,k)];

    x(:,k+1) = As*x(:,k) + Bs*U;
    for n=1:N
        y(n,k) = x(2*n,k) + [R0(n) zeros(1,n-1) R0(n) zeros(1,N-n)]*(U) + Vemf(n);
    end
    if max(y(:,k)<2.5)
        ending_search = k;
        y_low_violated = 1;
        break
    else
        ending_search = k;
    end
end

ending_search = k;
ending = ending_search;

figure;hold on;
for n=1:N
   plot(y(n,1:ending_search-1)) 
end
y_start = y;

figure;hold on;
for n=1:N
   plot(x(2*n-1,1:ending_search)) 
end
x_start = x;

figure;hold on;
for n=1:N
   plot(C_left(n,1:ending_search)) 
end

figure;hold on;
for n=1:N
   plot(U_bal(n,1:ending_search)) 
end
legend
% 
% if P_original(ending)==P(ending_search) && y_low_violated == 1
%     ending = ending_search;
%     disp('Succes')
% %     pause
% else
%     disp('ERROR')
% %     pause
% end

close all
% ending = numel(P);

%% linearization
for ip=1:ending
    for n=1:N
        u_opt(2*ip-1,n) = w(ip);
        u_opt(2*ip,n) = U_bal(n,ip);
    end
end

epsilon = 0.005;
range = linspace(-epsilon,epsilon,3);
for n=1:N
    for k=1:ending       
        for i=1:numel(range)
            x_min = x(2*n-1,k)+range(i);
            
            Y(i) = EMF(x_min)+D(x_min)*D_var(n)*(u_opt(2*k-1,n)+u_opt(2*k,n))-D(x(2*n-1,k))*D_var(n)*(u_opt(2*k-1,n)+u_opt(2*k,n));  
            y_perfect(i) = EMF(x_min)+x(2*n,k)+D(x_min)*D_var(n)*(u_opt(2*k-1,n)+u_opt(2*k,n));
            
            Af = A(x_min)^AB_var(n);
            Bf = B(x_min)*AB_var(n);
            x_perfect(i) = Af*x(2*n,k) + Bf*(u_opt(2*k-1,n)+u_opt(2*k,n));

            Af = A(x(2*n-1,k))^AB_var(n);
            Bf = B(x(2*n-1,k))*AB_var(n);
            Y_X(i) = x_perfect(i)-(Af*x(2*n,k) + Bf*(u_opt(2*k-1,n)+u_opt(2*k,n)));
        end
        X = x(2*n-1,k)+range;
        gradY = (Y(end)-Y(1))/(sum(diff(range)));
        beta0(n,k) = -gradY*x(2*n-1,k)+Y(ceil(numel(range)/2));
        beta1(n,k) = gradY;

        gradX = (Y_X(end)-Y_X(1))/(sum(diff(range)));
        alpha0(n,k) = -gradX*x(2*n-1,k);
        alpha1(n,k) = gradX;
        
        xboundup(k,n) = min(1,x(2*n-1,k)+epsilon);
        xbounddown(k,n) = max(0,x(2*n-1,k)-epsilon);
        
        alpha2 = ((A(x(2*n-1,k)+epsilon)^AB_var(n)-(A(x(2*n-1,k)-epsilon))^AB_var(n))*x(2*n,k))/(2*epsilon) + ((u_opt(2*k-1,n)+u_opt(2*k,n))*(B(x(2*n-1,k)+epsilon)*AB_var(n)-(B(x(2*n-1,k)-epsilon)*AB_var(n))))/(2*epsilon);
        alpha3 = -(alpha2)*x(2*n-1,k);
        
        beta2 = ((EMF(x(2*n-1,k)+epsilon)-(EMF(x(2*n-1,k)-epsilon)))/(2*epsilon) + ((u_opt(2*k-1,n)+u_opt(2*k,n))*(D(x(2*n-1,k)+epsilon)*D_var(n)-(D(x(2*n-1,k)-epsilon)*D_var(n))))/(2*epsilon));
        beta3 = -(beta2)*x(2*n-1,k);
   end
end

% figure;plot(X,x_perfect);hold on;plot(X,A(x(2*n-1,k))^AB_var(n)*x(2*n,k)+B(x(2*n-1,k))*AB_var(n)*(u_opt(2*k-1,n)+u_opt(2*k,n))+alpha2*X+alpha3)
% figure;plot(X,y_perfect);hold on;plot(X,EMF(x(2*n-1,k))+x(2*n,k)+D(x(2*n-1,k))*D_var(n)*(u_opt(2*k-1,n)+u_opt(2*k,n))+beta2*X+beta3)

% figure;plot(x(2*n-1,:));hold on;plot(xboundup(:,n),'k');plot(xbounddown(:,n),'k')
% figure;plot(X,Y_X-(alpha0(n,k)+alpha1(n,k)*X));%hold on;plot(X,alpha0(n,k)+alpha1(n,k)*X)
% figure;plot(X,Y-(beta0(n,k)+beta1(n,k)*X));%hold on;plot(X,beta0(n,k)+beta1(n,k)*X)

% range = linspace(-epsilon,epsilon,21);
% for i=1:numel(range)
%     for j=1:numel(range)
%             x_min = x(2*n-1,k)+range(i);
%             
%             y_perfect(i,j) = EMF(x_min)+x(2*n,k)+D(x_min)*D_var(n)*(u_opt(2*k-1,n)+u_opt(2*k,n)+30*range(j));
%             y_approx(i,j) = EMF(x(2*n-1,k))+x(2*n,k)+D(x(2*n-1,k))*D_var(n)*(u_opt(2*k-1,n)+u_opt(2*k,n)+30*range(j))+beta2*(x_min)+beta3;
%             
%             Af = A(x_min)^AB_var(n);
%             Bf = B(x_min)*AB_var(n);
%             x_perfect(i,j) = Af*x(2*n,k) + Bf*(u_opt(2*k-1,n)+u_opt(2*k,n)+30*range(j));
%             x_approx(i,j) = A(x(2*n-1,k))^AB_var(n)*x(2*n,k)+B(x(2*n-1,k))*AB_var(n)*(u_opt(2*k-1,n)+u_opt(2*k,n)+30*range(j))+alpha2*(x_min)+alpha3;
%     end
% end
% 
% [X,Y] = ndgrid(range,30*range);
% figure;surf(X,Y,y_perfect-y_approx)
% xlabel('s');ylabel('u');zlabel('error')
% 
% figure;surf(X,Y,x_perfect-x_approx)
% xlabel('s');ylabel('u');zlabel('error')

%% Cost function formulation
lambda = ones(N,ending);
mu = ones(1,ending);
nu = ones(1,ending);
w_hat = [w];
x0 = [0.15 0]';
y_low = 2.6;

%% Initialization
lambda_saved = zeros(N*maxIter,ending);
mu_saved = zeros(maxIter,ending);
nu_saved = zeros(maxIter,ending);
lambda_error_saved = zeros(N*maxIter,ending);
mu_error_saved = zeros(maxIter,ending);
nu_error_saved = zeros(maxIter,ending);
options = optimoptions('quadprog');
options.Display = 'off';
options.Diagnostics = 'off';

%%
% load backup

%% constraint formulation
clear ub lb
for ip=1:ending
    if ip<ending
        ub((2*ip-1):(2*ip),1) = [w_hat(ip)+3; bal_lim];
        lb((2*ip-1):(2*ip),1) = [w_hat(ip)-3; -bal_lim];
    elseif ip == ending
        ub((2*ip-1):(2*ip),1) = [w_hat(ip)+3; 0];
        lb((2*ip-1):(2*ip),1) = [w_hat(ip)-3; 0];
    end
end
clear u_opt
for ip=1:ending
    for n=1:N
        u_opt(2*ip-1,n) = w(ip);
        u_opt(2*ip,n) = U_bal(n,ip);
    end
end

options=cplexoptimset('Display','off','TolFun',1e-8,'TolRLPFun',1e-8,'TolXInteger',1e-8);

x_min = 0;
C0_varied = C0*C0_var;
gamma_reg_values = [0];
gamma_reg = repmat(gamma_reg_values,1,ending);
gain=[1;1;1];
gamma_lambda = 5e-1;
gamma_mu = 5e-4;
gamma_nu = 5e-4;

ce = 0.9;
rho = 0.05;
betaa = 1.001;
xsi = 0.99;

gamma_p = 1;
gamma_d = 5e-4;

figure;hold on;grid;
tic
for iter = 1:maxIter
    disp(['Iteration ',num2str(iter)])
    U0 = u_opt;
    x_temp = x;    
    
    for n=1:N
        x_min = 0;
        
        %% construct matrices
        [phi,gamma,Cm,Dm,Xiu] = predictMatrix_constant_LTV_N_lin_full(beta1(n,:),ending,n,C0_varied,AB_var,D_var,A,B,D,x_temp,alpha1,alpha0);

        Aineq = -[Cm*gamma+Dm];
        Aineq = [Aineq;-gamma(1:2:end,:);gamma(1:2:end,:)];
        bineq = -y_low + Cm*(phi*x0)+ beta0(n,:)'+ Xiu';
        bineq = [bineq;-(xbounddown(:,n)).*ones(ending,1)+phi(1:2:end,:)*x0;(xboundup(:,n)).*ones(ending,1)-phi(1:2:end,:)*x0];
       
        [omega,psi,xi] = predictMatrix_variable_full_lin(nu,mu,gamma_lambda,Rb,lambda(n,:),w_hat,ending);
        H = 2*((gamma'*Cm'+Dm')*omega+psi+gamma(1:2:end,:)'*diag(gamma_reg)*gamma(1:2:end,:));
        F = ((omega'*((Cm*(phi*x0))+beta0(n,:)'+Xiu'))'+xi+(2*(phi(1:2:end,:)*x0)'.*gamma_reg*gamma(1:2:end,:))...
                -2*x_temp(2*n-1,1:ending).*gamma_reg*gamma(1:2:end,:));
        
        y_matrix(n,:) = -Aineq(1:ending,1:2*ending)*u_opt(:,n) + Cm*(phi*x0) + beta0(n,:)' + Xiu';
        x_matrix_test_first(:,n) = gamma(1:2:end,:)*u_opt(:,n)+phi(1:2:end,:)*x0;    

        %% Optimization
        if iter>1
             [u_opt(:,n),fval,exitflag,output] = cplexqp(1*(H+H')/2+diag(repmat([1-1 1-1],1,ending)),F',[Aineq],[bineq],[],[],lb,ub,[],options);      %
        elseif iter==1
            [u_opt(:,n),fval,exitflag,output] = cplexqp((H+H')/2+0*eye(size((H+H')/2,1)),F',[Aineq],[bineq],[],[],lb,ub,[],options);      %
        end
        
        u_opt(:,n) = U0(:,n) + gamma_p*(u_opt(:,n)-U0(:,n));
            
        if n==1
            x = x0;
            x = repmat(x,N,1);
        end
        
        for k = 1:ending
            As(2*n-1:2*n,2*n-1:2*n) = [1 0; 0 A(x(2*n-1,k))^AB_var(n)];
            Bs(2*n-1:2*n,1:2) = [1/(C0*C0_var(n)) 1/(C0*C0_var(n));B(x(2*n-1,k))*AB_var(n) B(x(2*n-1,k))*AB_var(n)];
            R0(n) = D(x(2*n-1,k))*D_var(n);
            Vemf(n) = EMF(x(2*n-1,k));

            x(2*n-1:2*n,k+1) = As(2*n-1:2*n,2*n-1:2*n)*x(2*n-1:2*n,k)+Bs(2*n-1:2*n,1:2)*u_opt(2*k-1:2*k,n);
            y(n,k) = x(2*n,k) + R0(n)*(u_opt(2*k-1,n)+u_opt(2*k,n)) + Vemf(n);
        end
        
        y_matrix(n,:) = -Aineq(1:ending,1:2*ending)*u_opt(:,n) + Cm*(phi*x0) + beta0(n,:)'+Xiu';
        x_matrix_test_first(:,n) = gamma(1:2:end,:)*u_opt(:,n)+phi(1:2:end,:)*x0;
        x_matrix_test(:,n) = gamma(2:2:end,:)*u_opt(:,n)+phi(2:2:end,:)*x0;
        
        %% Linearisation
        for k=1:ending
            alpha1(n,k) = ((A(x(2*n-1,k)+epsilon)^AB_var(n)-(A(x(2*n-1,k)-epsilon))^AB_var(n))*x(2*n,k))/(2*epsilon) + ((u_opt(2*k-1,n)+u_opt(2*k,n))*(B(x(2*n-1,k)+epsilon)*AB_var(n)-(B(x(2*n-1,k)-epsilon)*AB_var(n))))/(2*epsilon);
            alpha0(n,k) = -(alpha1(n,k))*x(2*n-1,k);

            beta1(n,k) = ((EMF(x(2*n-1,k)+epsilon)-(EMF(x(2*n-1,k)-epsilon)))/(2*epsilon) + ((u_opt(2*k-1,n)+u_opt(2*k,n))*(D(x(2*n-1,k)+epsilon)*D_var(n)-(D(x(2*n-1,k)-epsilon)*D_var(n))))/(2*epsilon));
            beta0(n,k) = -(beta1(n,k))*x(2*n-1,k)+EMF(x(2*n-1,k))+D(x(2*n-1,k))*D_var(n)*(u_opt(2*k-1,n)+u_opt(2*k,n))-D(x(2*n-1,k))*D_var(n)*(u_opt(2*k-1,n)+u_opt(2*k,n));
            
            xboundup(k,n) = min(1,x(2*n-1,k)+epsilon);
            xbounddown(k,n) = max(0,x(2*n-1,k)-epsilon);
        end
        
        % Update w_hat and errors
        for i=1:ending
            w_hat(i) = sum(u_opt(2*i-1,1:N))/N;
            error_lambda(n,i) = (u_opt(2*i-1,n)-w_hat(i));
            error_mu(i) = (y(1:N,i)'*u_opt(2*i,1:N)'+Rb*ones(1,N)*(u_opt(2*i,1:N).^2)');
            error_nu(i) = ((y(1:N,i)'*u_opt(2*i-1,1:N)')-P(i));       
        end

        % Save errors
        error_lambda_saved((N)*(iter-1)+n,:) = error_lambda(n,:);
        mu_error_saved((N)*(iter-1)+n,:) = error_mu;
        nu_error_saved((N)*(iter-1)+n,:) = error_nu;
        
        %% Save  
        % Save multipliers
        lambda_saved(N*iter-(N-1):N*iter,:) = lambda;
        mu_saved((N)*(iter-1)+n,:) = mu;
        nu_saved((N)*(iter-1)+n,:) = nu;
        
        % Update w_hat and errors
        for i=1:ending
            w_hat(i) = sum(u_opt(2*i-1,1:N))/N;
            error_lambda(n,i) = (u_opt(2*i-1,n)-w_hat(i));
            error_mu(i) = (y(1:N,i)'*u_opt(2*i,1:N)'+Rb*ones(1,N)*(u_opt(2*i,1:N).^2)');
            error_nu(i) = ((y(1:N,i)'*u_opt(2*i-1,1:N)')-P(i));       
        end

        % Save errors
        error_lambda_saved((N)*(iter-1)+n,:) = error_lambda(n,:);
        mu_error_saved((N)*(iter-1)+n,:) = error_mu;
        nu_error_saved((N)*(iter-1)+n,:) = error_nu;

        %% Save u_opt
        u_opt_saved(:,N*iter-(N-1):N*iter) = u_opt;
        
        %% store multipliers
        lambda_old = lambda(n,:);
        mu_old = mu;
        nu_old = nu;
        
        %% Update lagrange multipliers
        for i=1:ending
            lambda(n,i) = lambda(n,i) + gamma_lambda.*error_lambda(n,i);          
            mu(i) = max([1e-6,mu(i)+gamma_d.*error_mu(i)]);
            nu(i) = max([1e-6,nu(i)+gamma_d.*error_nu(i)]);
        end 
%         p(iter+1,:) = error_mu+error_nu+sum(error_lambda);
%         d(iter+1,:) = lambda(n,:).*error_lambda(n,:) + (gamma_lambda/2)*error_lambda(n,:).^2 + mu.*(y(n,:).*u_opt(2:2:end,n)'+Rb*(u_opt(2:2:end,n).^2)')+ nu.*((y(n,:).*u_opt(1:2:end,n)'));
        
%         p(iter+1,:) = (error_mu+error_nu);
%         d(iter+1,:) = (mu.*error_mu+ nu.*error_nu);

        p(iter+1,:) = (U0(:,n)-u_opt(:,n))'/gamma_p - (mu_old-mu)/2 - (nu_old-nu)/2;
        d(iter+1,:) = (mu_old-mu)/(2*gamma_d) + (nu_old-nu)/(2*gamma_p) - (U0(:,n)-u_opt(:,n))';
        
        for i=1:ending
            p_mult(2*i-1:2*i) = [1 1]*p(iter+1,i);
            d_mult(i) = [1]*d(iter+1,i);
        end
        
        R(iter+1) = (p(iter+1,:)*p(iter+1,:)')/(d(iter+1,:)*d(iter+1,:)');
        w_p(iter+1) = ((U0(:,n)-u_opt(:,n))'*p_mult')/(((U0(:,n)-u_opt(:,n))'*(U0(:,n)-u_opt(:,n)))*(p_mult*p_mult'));
        w_d(iter+1) = ((nu_old-nu+(mu_old-mu))*d_mult')/((nu_old-nu+(mu_old-mu))*(nu_old-nu+(mu_old-mu))'*(d_mult*d_mult'));
        if w_p(iter+1)>ce
            gamma_p = betaa*gamma_p;
        elseif w_p(iter+1)<0
            gamma_p = xsi*gamma_p;
        end
        if w_d(iter+1)>ce
            gamma_d = betaa*gamma_d;
        elseif w_d(iter+1)<0 
            gamma_d = xsi*gamma_d;
        end
        
        gamma_p = gamma_p*(R(iter+1))^rho;
        gamma_d = gamma_d*(R(iter+1))^-rho;
        
        gamma_p_stored(iter) = gamma_p;
        gamma_d_stored(iter) = gamma_d;
        scatter(iter,sum(error_mu(error_mu>0))+sum(error_nu(error_nu>0)))
        pause(0.0001)
    end

    %% x and y
        x_saved((2*N*iter-(2*N-1)):(2*N*iter),:) = x;
        y_saved((N*iter-(N-1)):N*iter,:) = y;
        x_2_matrix_saved((N*iter-(N-1)):N*iter,:) = x_matrix_test';
        y_matrix_saved((N*iter-(N-1)):N*iter,:) = y_matrix;

        if sum(mu_error_saved(N*iter,:)<=10^-3)==numel(mu_error_saved(iter,:)) && sum(nu_error_saved(N*iter,:)<=10^-3)==numel(nu_error_saved(iter,:))
%              save C:\Users\s136161\Documents\ACC_2019_Dual_results\trust_region_in_constraint\Succesful_result_Edited_LPV_longer_3...
%                 nu_error_saved mu_error_saved error_lambda_saved maxIter... 
%         lambda_saved mu_saved nu_saved ending w x y u_opt darkblue P...
%         gamma_lambda gamma_nu gamma_mu bal_lim N x_saved y_saved x_2_matrix_saved y_matrix_saved u_opt_saved  xboundup_saved xbounddown_saved
            disp('Optimisation succesful!')
            break
        end
        
    
%     if mod(iter/25,1)==0
%         save C:\Users\s136161\Documents\ACC_2019_Dual_results\trust_region_in_constraint\Succesful_result_Edited_LPV_longer_3...
%             nu_error_saved mu_error_saved error_lambda_saved maxIter... 
%     lambda_saved mu_saved nu_saved ending w x y u_opt darkblue P...
%     gamma_lambda gamma_nu gamma_mu bal_lim N x_saved y_saved x_2_matrix_saved y_matrix_saved u_opt_saved  xboundup_saved xbounddown_saved
%     end
     
end
toc

%% evaluate results
maxIter = iter;

green = [12 195 82] ./ 255;
darkblue = [1 17 181] ./ 255;
red = [255 0 0]./255;
color = [darkblue;red;green];

teal = [18 150 155] ./ 255;
lightgreen = [94 250 81] ./ 255;
green = [12 195 82] ./ 255;
lightblue = [8 180 238] ./ 255;
darkblue = [1 17 181] ./ 255;
yellow = [251 250 48] ./ 255;
peach = [251 111 66] ./ 255;
brown = [224 211 162]./255;
color = [teal;lightgreen;green;lightblue;darkblue;yellow;peach;[29 11 5]./255;[249 37 138]./255;[231 8 1]./255];

figure;hold on
for n=1:N
    plot(y(n,1:ending),'Color',color(n+3,:))
end
for n=1:N
    plot(y_start(n,1:ending),'Color',color(n+3,:),'LineStyle','--')
end

figure;hold on;
for n=1:N
    plot(x(2*n-1,1:end-1),'Color',color(n+3,:))
end
for n=1:N
    plot(x_start(2*n-1,1:end-1),'Color',color(n+3,:),'LineStyle','--')
end

u_opt = u_opt_saved(:,N*maxIter-(N-1):N*maxIter);

for i=1:ending
    for n=1:N
        w_opt(i,n) = u_opt(2*i-1,n);
        ubal(i,n) = u_opt(2*i,n);
    end
end

figure;hold on;
for n=1:N
    plot(w_opt(:,n),'Color',color(n,:))
end
for n=1:N
    plot(w(1:end),'k','LineStyle','--')
end

figure;hold on;
for n=1:N
    plot(ubal(:,n),'Color',color(n,:))
end

%% Multiplier evolution
mult = 254/(N*maxIter);
figure
hold on
subplot(3,1,1);hold on;grid
for iter = 1:maxIter
    color1 = [255-mult*iter 0 0] ./ 255;
    for n=1:N
        plot(lambda_saved(N*iter-(N-n),:),'Color',color1)
    end
%     pause
end
subplot(3,1,2);hold on;grid
for iter = 1:N*maxIter
    color1 = [mult*(N*maxIter)+1-mult*iter 17 181] ./ 255;
    plot(mu_saved(iter,:),'Color',color1)
%     pause
end
subplot(3,1,3);hold on;grid
for iter = 1:N*maxIter
    color1 = [mult*(N*maxIter)+1-mult*iter 17 181] ./ 255;
    plot(nu_saved(iter,:),'Color',color1)
%     pause
end

figure
hold on
subplot(3,1,1);hold on;grid
for iter = maxIter
    for n=1:N
        plot(lambda_saved(N*iter-(N-n),:),'Color',color(n,:))
    end
end
subplot(3,1,2);hold on;grid
for iter = N*maxIter
    color1 = [mult*(N*maxIter)+1-mult*iter 17 181] ./ 255;
    plot(mu_saved(iter,:),'Color',color1)
end
subplot(3,1,3);hold on;grid
for iter = N*maxIter
    color1 = [mult*(N*maxIter)+1-mult*iter 17 181] ./ 255;
    plot(nu_saved(iter,:),'Color',color1)
end

%% Error evolution
figure
hold on
subplot(3,1,1);hold on;grid
for iter = 1:maxIter
    color1 = [255-mult*iter 0 0] ./ 255;
    for n=1:N
        plot(error_lambda_saved(N*iter-(N-n),:),'Color',color1)
    end
%     pause
end
subplot(3,1,2);hold on;grid
for iter = 1:N*maxIter
    color1 = [mult*N*maxIter+1-mult*iter 17 181] ./ 255;
    plot(mu_error_saved(iter,:),'Color',color1)
%      pause
end
subplot(3,1,3);hold on;grid
for iter = 1:N*maxIter
    color1 = [mult*N*maxIter+1-mult*iter 17 181] ./ 255;
    plot(nu_error_saved(iter,:),'Color',color1)
%     pause
end

figure
hold on
subplot(3,1,1);hold on;grid
for iter = maxIter
    for n=1:N
        plot(error_lambda_saved(N*iter-(N-n),:),'Color',color(n,:))
    end
end
subplot(3,1,2);hold on;grid
for iter = N*maxIter
    color1 = [mult*N*maxIter+1-mult*iter 17 181] ./ 255;
    plot(mu_error_saved(iter,:),'Color',color1)
end
subplot(3,1,3);hold on;grid
for iter = N*maxIter
    color1 = [mult*N*maxIter+1-mult*iter 17 181] ./ 255;
    plot(nu_error_saved(iter,:),'Color',color1)
%     pause
end

figure
hold on
subplot(3,1,1);hold on;grid
for iter = 1:maxIter
    color1 = [mult*N*maxIter+1-mult*iter 17 181] ./ 255;
    scatter(iter,gain_saved(iter,1))
end
subplot(3,1,2);hold on;grid
for iter = 1:maxIter
    color1 = [mult*N*maxIter+1-mult*iter 17 181] ./ 255;
    scatter(iter,gain_saved(iter,2))
%     pause
end
subplot(3,1,3);hold on;grid
for iter = 1:maxIter
    color1 = [mult*N*maxIter+1-mult*iter 17 181] ./ 255;
    scatter(iter,gain_saved(iter,3))
%     pause
end

