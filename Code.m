%% COVID-19 Bangladesh Monte Carlo Simulation Project

clear; clc; close all;

%% Step 1: Load and Prepare Data
fprintf('Loading Bangladesh COVID-19 data...\n');

% Read the CSV file (make sure the file is in your current directory)
data = readtable('COVID-19-Bangladesh.csv');

% Extract key variables
dates = datetime(data.date, 'InputFormat', 'yyyy-MM-dd');
total_cases = data.total_confirmed;
new_cases = data.new_confirmed;
active_cases = data.active;
recovery_rate = data.recoveryRate___ / 100; % Convert percentage to decimal
mortality_rate = data.mortalityRate___ / 100;

% Remove any NaN values and get valid data points
valid_idx = ~isnan(new_cases) & new_cases >= 0;
dates = dates(valid_idx);
new_cases = new_cases(valid_idx);
total_cases = total_cases(valid_idx);
active_cases = active_cases(valid_idx);

fprintf('Data loaded: %d days of COVID-19 data\n', length(dates));

%% Step 2: Calculate Historical Parameters
fprintf('Calculating historical parameters...\n');

% Calculate growth rates (excluding zeros and negatives)
growth_rates = [];
for i = 2:length(total_cases)
    if total_cases(i-1) > 0 && total_cases(i) > total_cases(i-1)
        growth_rate = (total_cases(i) - total_cases(i-1)) / total_cases(i-1);
        growth_rates = [growth_rates; growth_rate];
    end
end

% Statistical parameters for Monte Carlo
mean_growth_rate = mean(growth_rates);
std_growth_rate = std(growth_rates);
mean_new_cases = mean(new_cases(new_cases > 0));
std_new_cases = std(new_cases(new_cases > 0));

fprintf('Mean daily growth rate: %.4f ± %.4f\n', mean_growth_rate, std_growth_rate);
fprintf('Mean new cases per day: %.1f ± %.1f\n', mean_new_cases, std_new_cases);

%% Step 3: Monte Carlo Simulation Setup
fprintf('Setting up Monte Carlo simulation...\n');

% Simulation parameters
num_simulations = 1000;        % Number of Monte Carlo runs
prediction_days = 30;          % Predict next 30 days
initial_cases = total_cases(end); % Start from last known total

% Create arrays to store results
all_predictions = zeros(num_simulations, prediction_days);
all_daily_new = zeros(num_simulations, prediction_days);

%% Step 4: Run Monte Carlo Simulation
fprintf('Running %d Monte Carlo simulations...\n', num_simulations);

for sim = 1:num_simulations
    % Initialize for this simulation
    current_total = initial_cases;
    prediction = zeros(1, prediction_days);
    daily_new = zeros(1, prediction_days);
    
    for day = 1:prediction_days
        % Generate random parameters for this day
        % Use normal distribution with historical mean and std
        random_growth = normrnd(mean_growth_rate, std_growth_rate);
        random_new_cases = max(0, normrnd(mean_new_cases, std_new_cases));
        
        % Apply some realistic constraints
        random_growth = max(-0.1, min(0.3, random_growth)); % Cap growth between -10% and 30%
        
        % Calculate new cases for this day
        if rand < 0.7  % 70% chance of using growth-based model
            new_cases_today = current_total * abs(random_growth);
        else  % 30% chance of using average-based model
            new_cases_today = random_new_cases;
        end
        
        % Add some random noise
        noise_factor = 1 + normrnd(0, 0.1); % ±10% noise
        new_cases_today = max(0, new_cases_today * noise_factor);
        
        % Update totals
        current_total = current_total + new_cases_today;
        prediction(day) = current_total;
        daily_new(day) = new_cases_today;
    end
    
    all_predictions(sim, :) = prediction;
    all_daily_new(sim, :) = daily_new;
    
    % Progress indicator
    if mod(sim, 100) == 0
        fprintf('Completed %d/%d simulations\n', sim, num_simulations);
    end
end

%% Step 5: Analyze Results and Calculate Statistics
fprintf('Analyzing Monte Carlo results...\n');

% Calculate statistics
mean_prediction = mean(all_predictions, 1);
std_prediction = std(all_predictions, 1);
percentile_5 = prctile(all_predictions, 5, 1);
percentile_95 = prctile(all_predictions, 95, 1);
median_prediction = median(all_predictions, 1);

% Future dates for prediction
future_dates = dates(end) + days(1:prediction_days);

%% Step 6: Visualization
fprintf('Creating visualizations...\n');

% Figure 1: Historical Data and Predictions
figure('Position', [100, 100, 1200, 800]);

subplot(2, 2, 1);
plot(dates, total_cases, 'b-', 'LineWidth', 2);
hold on;
plot(future_dates, mean_prediction, 'r-', 'LineWidth', 2);
fill([future_dates, fliplr(future_dates)], ...
     [percentile_5, fliplr(percentile_95)], ...
     'r', 'FaceAlpha', 0.2, 'EdgeColor', 'none');
xlabel('Date');
ylabel('Total Confirmed Cases');
title('COVID-19 Cases: Historical Data and Monte Carlo Prediction');
legend('Historical Data', 'Mean Prediction', '90% Confidence Interval', 'Location', 'northwest');
grid on;

% Figure 2: Daily New Cases Prediction
subplot(2, 2, 2);
daily_new_mean = mean(all_daily_new, 1);
daily_new_std = std(all_daily_new, 1);
plot(future_dates, daily_new_mean, 'g-', 'LineWidth', 2);
hold on;
fill([future_dates, fliplr(future_dates)], ...
     [daily_new_mean - daily_new_std, fliplr(daily_new_mean + daily_new_std)], ...
     'g', 'FaceAlpha', 0.2, 'EdgeColor', 'none');
xlabel('Date');
ylabel('Daily New Cases');
title('Predicted Daily New Cases');
legend('Mean Prediction', '±1 Standard Deviation', 'Location', 'best');
grid on;

% Figure 3: Uncertainty Analysis
subplot(2, 2, 3);
plot(1:prediction_days, std_prediction, 'mo-', 'LineWidth', 2);
xlabel('Days into Future');
ylabel('Standard Deviation');
title('Prediction Uncertainty Over Time');
grid on;

% Figure 4: Distribution of Final Predictions
subplot(2, 2, 4);
histogram(all_predictions(:, end), 30, 'FaceColor', 'cyan', 'FaceAlpha', 0.7);
xlabel('Total Cases after 30 days');
ylabel('Frequency');
title('Distribution of 30-day Predictions');
grid on;

%% Step 7: Summary Statistics and Risk Analysis
fprintf('\n=== MONTE CARLO SIMULATION RESULTS ===\n');
fprintf('Prediction Period: %d days\n', prediction_days);
fprintf('Number of Simulations: %d\n', num_simulations);
fprintf('\nCurrent Total Cases: %d\n', initial_cases);
fprintf('\n30-Day Predictions:\n');
fprintf('  Mean Prediction: %.0f cases\n', mean_prediction(end));
fprintf('  Median Prediction: %.0f cases\n', median_prediction(end));
fprintf('  95%% Confidence Interval: [%.0f, %.0f] cases\n', percentile_5(end), percentile_95(end));

% Risk analysis
risk_threshold = initial_cases * 1.5; % 50% increase threshold
risk_probability = sum(all_predictions(:, end) > risk_threshold) / num_simulations * 100;
fprintf('\nRisk Analysis:\n');
fprintf('  Probability of exceeding %.0f cases: %.1f%%\n', risk_threshold, risk_probability);

% Best and worst case scenarios
best_case = min(all_predictions(:, end));
worst_case = max(all_predictions(:, end));
fprintf('  Best case scenario: %.0f cases\n', best_case);
fprintf('  Worst case scenario: %.0f cases\n', worst_case);
fprintf('\nSimulation completed successfully!\n');

%% Step 9: Parameter Sensitivity Analysis (Bonus)
fprintf('\nRunning sensitivity analysis...\n');

% Test different growth rate assumptions
growth_scenarios = [mean_growth_rate * 0.5, mean_growth_rate, mean_growth_rate * 1.5];
scenario_names = {'Conservative', 'Expected', 'Aggressive'};

figure('Position', [200, 200, 1000, 600]);
colors = ['b', 'r', 'g'];

for s = 1:length(growth_scenarios)
    scenario_predictions = zeros(100, prediction_days); % Fewer simulations for speed
    
    for sim = 1:100
        current_total = initial_cases;
        prediction = zeros(1, prediction_days);
        
        for day = 1:prediction_days
            random_growth = normrnd(growth_scenarios(s), std_growth_rate * 0.5);
            random_growth = max(-0.05, min(0.2, random_growth));
            new_cases_today = current_total * abs(random_growth);
            current_total = current_total + new_cases_today;
            prediction(day) = current_total;
        end
        
        scenario_predictions(sim, :) = prediction;
    end
    
    scenario_mean = mean(scenario_predictions, 1);
    plot(1:prediction_days, scenario_mean, [colors(s) '-'], 'LineWidth', 2);
    hold on;
end

xlabel('Days into Future');
ylabel('Total Cases');
title('Sensitivity Analysis: Different Growth Rate Scenarios');
legend(scenario_names, 'Location', 'northwest');
grid on;

fprintf('Sensitivity analysis completed!\n');
fprintf('\n=== PROJECT COMPLETED ===\n');
