path = "C:\Users\lenna\Desktop\BA\code\results\Basler\led\";
names = ["0_deg.png","45_deg.png","90_deg.png","135_deg.png"];

example_data = false;
threshold_mask = false;
drawing_mask = true;

addpath("utils")
if(example_data)
    % Load raw images, mask and specular mask
    load sampleData.mat
else
    %% Stack the image of four polarization angles into an image of four channels
    for i = [1, 2, 3, 4]
        images(:, :, i) = imread(path + names(i));
    end
    images = im2double(images);
    %% Assign polarizaton angles to corresponding channels
    angles = [0, 45, 90, 135] * pi / 180;

    %% May create a mask for a region of interest
    if ( threshold_mask )
        mask = ones(size(images(:, :, 1)));
        image_avg = mean(double(images), 3);
        fg_threshold = 10;
        mask(image_avg < fg_threshold)  = 0;
        mask(image_avg >=fg_threshold)  = 1; % foreground
        mask = logical(mask);
        figure('Name','Threshold Mask', 'NumberTitle', 'off'); imagesc(mask)
    end
    
    if (drawing_mask)
        L = imread(path + names(1));
        imshow(L)
        h1 = drawpolygon();
        roiPoints = h1.Position;
        mask = poly2mask(roiPoints(:,1),roiPoints(:,2),size(L,1),size(L,2));
        figure('Name','Drawing Mask', 'NumberTitle', 'off'); imshow(mask)
    end

end

% Estimate polarisation image from captured images
if (threshold_mask || drawing_mask)
    [ rho_est,phi_est,Iun_est ] = PolarisationImage( images,angles,mask,'nonlinear' );
else 
    [ rho_est,phi_est,Iun_est ] = PolarisationImage( images,angles );
end
figure('Name','Rho', 'NumberTitle', 'off'); imshow(rho_est); colorbar % < 2 // für nonlinear max 0.8138
figure('Name','Phi', 'NumberTitle', 'off'); imshow(phi_est); colorbar % < 4 // für nonlinear max 3.1416
figure('Name','Iun', 'NumberTitle', 'off'); imshow(Iun_est); colorbar

prozent = Iun_est .\ imread(path + names(1)) * 100;
figure('Name','Iun  pro', 'NumberTitle', 'off'); imshow(prozent); colorbar

% Assume refractive index = 1.5
n = 1.5;

% Estimate light source direction from diffuse pixels (note that you might
% get a convex/concave flip)
%[ s,T,B ] = findLight( theta_est,phi_est,Iun_est,mask&~spec,3 );
% Or use known direction and estimate albedo
s = [2 0 7]';
[ s,T,B ] = findLight( theta_est,phi_est,Iun_est,mask&~spec,3,s );

% Compute angles, taking into account different model for specular pixels
theta_est_combined = rho_diffuse(rho_est,n);
theta_s = rho_spec(rho_est(spec),n);
theta_est_combined(spec)=theta_s;
phi_est_combined = phi_est;
phi_est_combined(spec)=mod(phi_est(spec)+pi/2,pi);

% Compute boundary prior azimuth angles and weight
[ azi,Bdist ] = boundaryPrior( mask );

% Run linear height from polarisation
[ height ] = HfPol( theta_est_combined,min(1,Iun_est),phi_est_combined,s,mask,false,spec );

% Visualise
figure;
surf(height,'EdgeColor','none','FaceColor',[0 0 1],'FaceLighting','gouraud','AmbientStrength',0,'DiffuseStrength',1); axis equal; light