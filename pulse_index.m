function index = pulse_index(signal,threshold,pos_neg)

    signal = signal(:);
    signal = signal > threshold;
    difference = [0; diff(signal)];
    
    if pos_neg
        index = find(difference == 1);
    else
        index = find(difference == -1);
    end
    
end