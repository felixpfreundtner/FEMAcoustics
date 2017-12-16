% FEM 1-D Scalar Analysis
% 1D Acoustics
% Plot: geometry, mesh, boundary nodes, and field

% Generate mesh data: mesh, boundary nodes, domains (COMSOL is used as a mesh
% generator)


%% Input data
rho0=1.2; % Fluid density
c0=342.2; % Speed of sound
neta_a=0.00; % Damping in the cavity
U0=1; % Piston displacement

%%
%==================================================================
% Parameters definition
% **************************************************************
L=1; % Length of the tube
piston_x = 1; % Piston x position 
boundary_x = 0; % Wall boundary x position 
freq = [10:2:1000]; % Frequency of piston excitation
Z = 2055-4678i; % % Wall impedance defined as pressure at wall divided by particle velocity Z=p/v
air_damp = 0.00; % Damping of the cavity air
rho0 = 1.2; % Air density in kg/m^3
c0 = 340; % Speed of sound in m/s
shape_type = 2; % 1 - linear shape functions; 2 - quadratic shape functions 
solver = 1; % 1 - sparse matrix solver; 2 - GMRES iterative solver
% *************************************************************************

%% Acoustical properties calculation

% Boundary
Z0 = rho0 * c0; % Calculate impedance of air
if (Z~=0), beta= 1/Z; else beta=1e6; end % Calculate wall admittance

% Excitation
omega=2*pi*freq; % Calculate angular frequency of loudspeaker excitation frequency
lamda = c0./freq; % Calculate wave length of loudspeaker excitation frequency
lamda_min = c0/max(freq); % Smallest wavelength in the room
k0 = omega /c0; % wave number

%% Generate Mesh
Ne_per_lamda_min = 6; % minimum number of elements per wavelength
Ne = ceil(Ne_per_lamda_min * L / lamda_min); % Total number of elements 
Nn = shape_type*Ne + 1; % Total number of nodes
Ne_Nn = shape_type + 1; % Number of nodes per element
h=L/Ne; % Element length
x = 0:h/shape_type:L; % Coordinates 
[~, piston_node] = min(abs(x - piston_x));
[~, boundary_node] = min(abs(x - boundary_x));
%% Compute elementary matrices
switch shape_type
    case 1  
        Ke = [1,-1;-1,1]*1/h; % *c0^2 
        Me = [2,1;1,2]*h/6;
    case 2
        % He = [7,-8,1;-8,16,-8;1,-8,7]/(3*h)/rho0;
        % Qe = [4,2,-1;2,16,2;-1,2,4]*h/30/(rho0*c0^2);
        Ke = [7,-8,1;-8,16,-8;1,-8,7]/(3*h); % *c0^2 
        Me = [4,2,-1;2,16,2;-1,2,4]*h/30;
end
%% Assemble stiffness and mass matrix

I=eye(Ne_Nn,Ne_Nn);
K=sparse(Nn,Nn); M = sparse(Nn,Nn);
for e=1:Ne
    LM = sparse(Ne_Nn,Nn); 
    LM(:,(Ne_Nn-1)*e-(Ne_Nn-2):(Ne_Nn-1)*e+1)=I;
    K = K + LM'*Ke*LM;
    M = M + LM'*Me*LM;
end
    
%% Step 4: Impedance condition (damping by wall)
C = zeros(Nn,Nn);
C(boundary_node,boundary_node) = beta;
%% Step 5: Solving the system with the Force vector : Piston at a x=L
Pquad_direct=zeros(1,Nn);
Pquad_modal=zeros(1,Nn);
Pquad_exact=zeros(1,Nn);
for n=1:length(omega)
    w=omega(n);
    F=zeros(Nn,1); % Force vector
    F(piston_node) = w^2; % at piston position * rho0*co^2 (dividee whole P by it)
    A_solve = (K/rho0 - w^2*M/((rho0*c0^2)*(1+1i*air_damp))+1i*w*C/(rho0*c0));
    P = A_solve\F; % Solve the system to get pressure in tube
    Pquad_direct(n) = (rho0*c0^2)* real(P'*M*P)/(2*L)/(rho0*c0^2); % space avergaed quadratic pressure /(rho0*c0^2) because of M
    
    % Analytical solution
    k0=w/c0/sqrt(1+1i*air_damp);
    r=(Z-1)/(Z+1);
    a=(1j*w*U0)*Z0/(exp(1j*k0*L)-r*exp(-1j*k0*L));
    x=[0:L/100:L]; p=a*(exp(-1i*k0*x)+r*exp(1i*k0*x));
    Pquad_exact(n) = real(norm(p)^2/length(x)/2);
end

% Step 6: Comparison with the exact solution
plot(freq,10*log10(Pquad_direct(1:length(freq))),'k','LineWidth',2)
hold on
plot(freq,10*log10(Pquad_exact(1:length(freq))),':','LineWidth',2,'Color',[0.5 0.5 0.5])
xlabel('Frequency (Hz)');
ylabel(' Quadratic pressure (dB ref.1)');
legend('Analytical', 'FEM ');
text(100 , 95,['Analytical vs. FEM using ', num2str(Ne), ' quadratic elements'],'Color','k','FontSize',12)
text(100 , 90,['Specified normalized Impedance Z = ', num2str(Z)],'FontSize',12)
