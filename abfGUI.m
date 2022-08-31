classdef abfGUI < handle
    %to do
    %grab and move threshold with cursor
    %show number of events detected per channel
    %interval threshold selection per channel
    %save time points into file
    %filename, chname, time points, amplitudes, interval threshold
    
    
    properties (Access = private)
        
        %figure 
        f
        loadButton
        controlPanel
        ax
        axPanel
        filenameEditfield 
        plotter
        borderOffset = 5
        forwardButton
        backwardButton
        zoomObj
        panObj
        tempX
        tempY
        filenameLabel
        thresholdLine
        thresholdCbx
        axMousePoint
        changeWindowLabel
        detectEventsButton
        detectedPoints
        uit
        minIntervalLabel 
        intervalEditfield
        exportTracesCbx
        exportButton
        
        %variables
        filename
        filePath
        record
        si
        recordHandle
        channelName
        channelNumber
        channelSelecterDD
        t
        tWindow
        windowSize = 10;
        plotIndices
        plottedChannel = 1
        width
        movingThreshold
        channelEvents;
        firstTime
        lastTime
        ADCScalingVoltage;
        %table
        input;
        name; 
        event_count;
        threshold;
        interval_thres;
        dataTable = [];
        
        
    end
    
    methods
        
        function this = abfGUI()
            
            %build channel structure
            for i = 1:16
                
                this.channelEvents(i).name              = [];
                this.channelEvents(i).eventIndex        = [];
                this.channelEvents(i).eventTime         = [];
                this.channelEvents(i).eventInterval     = [];
                this.channelEvents(i).threshold         = [];
                this.channelEvents(i).interval_thres    = [];
                
            end
            
            this.tWindow = [0 this.windowSize]; %in seconds

            this.f = uifigure('Name','.abf preprocessing','WindowButtonMotionFcn', @this.hoverCallback);
            this.ax = uiaxes('Parent',this.f,'Position',[this.borderOffset 200 550 200]);
            this.ax.XLabel.String = 'time (sec)';
            this.ax.YLabel.String = 'voltage (V)';
            this.ax.TickDir = 'out';
            this.ax.TickLength = [0.005 0.005];
            this.plotter = plot(this.ax,[NaN NaN],[NaN NaN]);
            hold(this.ax);
            this.detectedPoints = plot(this.ax,[NaN NaN],[NaN NaN],'.r');
            this.thresholdLine = plot(this.ax,[NaN NaN],[NaN NaN],'r');
            
            this.ax.ButtonDownFcn = @this.plotClicked;
            this.plotter.ButtonDownFcn = @this.plotClicked;
            this.thresholdLine.ButtonDownFcn = @this.plotClicked;
            this.detectedPoints.ButtonDownFcn = @this.plotClicked;
            
            this.controlPanel = uipanel('Parent',this.f,'Position',[this.borderOffset this.borderOffset this.f.Position(3)-(2*this.borderOffset) 150],'AutoResizeChildren','off','Title','Controls');
            this.thresholdCbx = uicheckbox(this.controlPanel, 'Text','threshold',...
                'ValueChangedFcn',@(thresholdCbx,event) this.thresholdCbxChanged());
            this.exportTracesCbx = uicheckbox(this.controlPanel, 'Text','export traces');
            this.loadButton = uibutton(this.controlPanel,'push','Text', 'load .abf',...
                'ButtonPushedFcn', @(loadButton,event) this.loadButtonPushed());
            this.exportButton = uibutton(this.controlPanel,'push','Text', 'export',...
                'ButtonPushedFcn', @(exportButton,event) this.exportButtonPushed());
            this.forwardButton = uibutton(this.controlPanel,'push','Text', '>',...
                'ButtonPushedFcn', @(forwardButton ,event) this.arrowButtonPushed(forwardButton));
            this.backwardButton = uibutton(this.controlPanel,'push','Text', '<',...
                'ButtonPushedFcn', @(backwardButton,event) this.arrowButtonPushed(backwardButton));
            this.detectEventsButton = uibutton(this.controlPanel,'push','Text', 'detect',...
                'ButtonPushedFcn', @(detectEventsButton,event) this.detectEventsButtonPushed());
            this.channelSelecterDD = uidropdown(this.controlPanel,'Items',{''},...
                'ValueChangedFcn',@(channelSelecterDD,event) this.channelSelecterDDChanged(channelSelecterDD));
            this.filenameEditfield = uieditfield(this.controlPanel,'Enable','on','Editable','off');
            this.intervalEditfield = uieditfield(this.controlPanel,'numeric','Limits', [0 Inf],'ValueChangedFcn',@(intervalEditfield,event) this.intervalEditfieldChanged());
            this.filenameLabel = uilabel(this.controlPanel,'Text','filename:');
            this.minIntervalLabel = uilabel(this.controlPanel,'Text','min inter.:');
            
            this.uit = uitable(this.controlPanel,'Data',this.dataTable);
            
            buttonHeight = 19;
            buttonWidth = 70;
            topRow = this.controlPanel.Position(4) - 44;
            
            this.backwardButton.Position = [this.borderOffset ...
                topRow ...
                buttonWidth ...
                buttonHeight];
            
            this.forwardButton.Position = [this.borderOffset+buttonWidth ...
                this.backwardButton.Position(2) ...
                buttonWidth ...
                buttonHeight];
            
            this.exportTracesCbx.Position = [this.borderOffset ...
                this.borderOffset + 3 ...
                buttonWidth*1.24 ...
                buttonHeight];
            
            this.exportButton.Position = [this.exportTracesCbx.Position(1) + this.exportTracesCbx.Position(3) + 10 ...
                this.exportTracesCbx.Position(2) ...
                buttonWidth*1.6 ...
                buttonHeight];
            
            this.loadButton.Position = [this.borderOffset  ...
                this.borderOffset + buttonHeight + 9 ...
                buttonWidth ...
                buttonHeight];
            
            this.filenameLabel.Position = [this.loadButton.Position(1)+buttonWidth+5 ...
               this.loadButton.Position(2) ...
               buttonWidth ...
               buttonHeight];
                                       
            this.filenameEditfield.Position = [this.filenameLabel.Position(1)+buttonWidth-15 ...
               this.filenameLabel.Position(2) ...
               buttonWidth+10 ...
               buttonHeight];  
                                       
            this.channelSelecterDD.Position = [this.borderOffset ...
                topRow-(1.3*buttonHeight) ...
                buttonWidth ...
                buttonHeight];
            
            this.thresholdCbx.Position = [this.channelSelecterDD.Position(1)+buttonWidth+5 ...
              this.channelSelecterDD.Position(2) ...
              buttonWidth+10 ...
              buttonHeight];
                                      
            this.minIntervalLabel.Position   = [this.thresholdCbx.Position(1) ...
                this.thresholdCbx.Position(2)-buttonHeight-5 ...
                buttonWidth...
                buttonHeight];
                                            
            this.intervalEditfield.Position = [this.filenameLabel.Position(1)+buttonWidth-15 ...
                                           this.minIntervalLabel.Position(2) ...
                                           buttonWidth+10 ...
                                           buttonHeight];    
                                       
            this.detectEventsButton.Position = [this.channelSelecterDD.Position(1)+(2*buttonWidth)+5 ...
                                          this.channelSelecterDD.Position(2) ...
                                          buttonWidth-5 ...
                                          buttonHeight];                                       
            
            this.uit.Position = [this.detectEventsButton.Position(1)+buttonWidth+this.borderOffset ...
                                    this.borderOffset ...
                                    430 ... 
                                    this.controlPanel.Position(4)-this.borderOffset*6];
                                
            
            this.zoomObj = zoom(this.ax);
            set(this.zoomObj, 'ActionPostCallback',@(zoomObj,event) this.zoomChanged());
            this.panObj = pan(this.f);
            set(this.panObj, 'ActionPostCallback',@(panObj,event) this.panChanged());
            set(this.f,'AutoResizeChildren','off','ResizeFcn',@(f,event) this.resizeCallback());
            
            this.plotRecord();
            
        end
        
    end
    
    methods (Access = private)
        
        function exportButtonPushed(this)
            
            for i = 1:size(this.channelEvents,2)
                
                channelEvents(i).name           = this.channelEvents(i).name;
                channelEvents(i).eventTime      = this.channelEvents(i).eventTime;
                channelEvents(i).threshold      = this.channelEvents(i).threshold;
                channelEvents(i).interval_thres = this.channelEvents(i).interval_thres;
                
            end
            
            del = cellfun(@isempty,{channelEvents.name});
            channelEvents(del) = [];
            
            save('channelEvents.mat','channelEvents')
            disp('channelEvents saved')
            
            if this.exportTracesCbx.Value
                
                traces                  = this.record;
                info.name               = this.channelName;
                info.ADCScalingVoltage  = this.ADCScalingVoltage;
                info.samplingInterval   = this.si;
                
                save('traces.mat','traces','info','-v7.3')
                
                disp('traces saved')

            end     
            
        end
        
        function intervalEditfieldChanged(this)
            
        end
        
        function applyIntervalThreshold(this)
            
            if numel(this.channelEvents(this.plottedChannel).eventIndex) > 0 || this.intervalEditfield.Value == 0
                
                del = this.channelEvents(this.plottedChannel).eventInterval < this.intervalEditfield.Value;
               
                this.channelEvents(this.plottedChannel).eventIndex(del)  = [];      
                this.channelEvents(this.plottedChannel).eventTime(del)     = [];           
                this.channelEvents(this.plottedChannel).eventInterval(del) = [];  
                
                this.uit.Data.event_count{this.plottedChannel}             = numel(this.channelEvents(this.plottedChannel).eventIndex);
                this.uit.Data.interval_thres{this.plottedChannel}          = this.intervalEditfield.Value;
                
                this.plotRecord();
                
            end
            
        end
        
        function plotClicked(this,src,event)
            
            if ~this.movingThreshold
                this.movingThreshold = 1;
            else
                this.movingThreshold = 0;
            end
            
        end
        
        function hoverCallback(this,src,event)
            
            fMousePoint = get(this.f, 'CurrentPoint');
            
            xSearch = [this.ax.Position(1)...
                this.ax.Position(1)+this.ax.Position(3)...
                this.ax.Position(1)+this.ax.Position(3)...
                this.ax.Position(1)];
            
            ySearch = [this.ax.Position(2)...
                this.ax.Position(2)...
                this.ax.Position(2)+this.ax.Position(4)...
                this.ax.Position(2)+this.ax.Position(4)];
            
            if inpolygon(fMousePoint(1,1),fMousePoint(1,2),xSearch,ySearch)
                
                this.axMousePoint = get(this.ax, 'CurrentPoint');
                
            end
            
            if this.movingThreshold
                this.thresholdLine.YData = [this.axMousePoint(1,2) this.axMousePoint(1,2)];
            end
            
        end
        
        function thresholdCbxChanged(this)
            if this.thresholdCbx.Value

                if isempty( this.uit.Data.threshold{this.plottedChannel} )
                    yLim = this.ax.YLim;
                    yMean = ( yLim(1) + yLim(2) / 2);
                    this.thresholdLine.YData = [yMean yMean];
                else
                    this.thresholdLine.YData = [this.uit.Data.threshold{this.plottedChannel}     this.uit.Data.threshold{this.plottedChannel}];  
                end
                
            else
                this.thresholdLine.XData = [NaN NaN];
                this.thresholdLine.YData = [NaN NaN];
            end
            this.plotRecord();
            
        end
        
        function zoomChanged(this) 

            this.updateWindow();

        end
        
        function panChanged(this)
            
            this.updateWindow();
            
        end
        
        function updateWindow(this)
            
            xLim = this.ax.XLim;
            this.tWindow = [xLim(1) xLim(2)];
            this.windowSize = xLim(2) - xLim(1);
            this.plotRecord();
            
        end
        

        
        function resizeCallback(this)
            
            x = this.controlPanel.Position(1);
            y = this.controlPanel.Position(2);
            h = this.controlPanel.Position(4);
            w = this.f.Position(3)-x*2;
            this.changeObjDimensions(this.controlPanel,x,y,h,w);
            
            x = this.uit.Position(1);
            y = this.uit.Position(2);
            h = this.uit.Position(4);
            w = this.f.Position(3)- this.uit.Position(1) - this.borderOffset*3.4;
            this.changeObjDimensions(this.uit,x,y,h,w);
            
            x = 10;
            y = this.controlPanel.Position(2) + this.controlPanel.Position(4) + x;
            h = this.f.Position(4) - y - x;
            w = this.f.Position(3) - x*2;
            this.changeObjDimensions(this.ax,x,y,h,w);
            this.plotRecord();
            
        end
        
        function changeObjDimensions(this,obj,x,y,h,w)
            if h >= 0 && w >= 0 && x >= 0 && y >= 0
                obj.Position = [x y w h];
            end
        end
        
        function loadButtonPushed(this)
            
            [this.filename this.filePath] = uigetfile('.abf');
            this.filenameEditfield.Value = this.filename;
            [this.record,this.si,this.recordHandle] = abfLoadLight([this.filePath this.filename],'start',0,'stop','e');            
            this.channelNumber = this.recordHandle.nADCSamplingSeq;
            this.channelName = this.recordHandle.recChNames;
            this.channelSelecterDD.Items = this.channelName;
            this.ADCScalingVoltage = this.recordHandle.fADCRange / this.recordHandle.lADCResolution;
            this.si = this.si/1000000;
            this.t = ( (1:this.recordHandle.dataPtsPerChan)-1 )*(this.si);
            this.t = this.t(:);
            
            channelCount = numel(this.channelNumber);
            
            this.input   = cell(channelCount,1); 
            this.name = cell(channelCount,1); 
            this.event_count = cell(channelCount,1);
            this.threshold = cell(channelCount,1);
            this.interval_thres = cell(channelCount,1);
            
            for i = 1:channelCount
                this.input(i) = {['IN ' num2str( this.channelNumber(i) )]};
                this.name(i)  = this.channelName(i);
                this.event_count(i) = {0};
            end

            this.makeTable();
            this.uit.Data = this.dataTable;
            this.plotRecord();
            
        end
        
        function makeTable(this)
            
            input = this.input;
            name = this.name;
            event_count = this.event_count;
            threshold = this.threshold;
            interval_thres = this.interval_thres;
            this.dataTable = table(input,name,event_count,threshold,interval_thres);
            
        end
        
        function detectEventsButtonPushed(this)
            
            if ~this.thresholdCbx.Value
                return
            end
            
            threshold                                                 = this.thresholdLine.YData(1)/(this.ADCScalingVoltage); %convert threshold into int16    
            index                                                     = pulse_index(this.record(:,this.plottedChannel),threshold,1);
            
            this.channelEvents(this.plottedChannel).name              = this.channelName{this.plottedChannel};
            this.channelEvents(this.plottedChannel).eventIndex        = index;
            this.channelEvents(this.plottedChannel).eventTime         = this.t(index);
            this.channelEvents(this.plottedChannel).eventInterval     = [Inf; diff(this.channelEvents(this.plottedChannel).eventTime(:))];
            this.channelEvents(this.plottedChannel).threshold         = this.thresholdLine.YData(1);
            this.channelEvents(this.plottedChannel).interval_thres    = this.intervalEditfield.Value;
            
            this.uit.Data.threshold{this.plottedChannel}              = this.thresholdLine.YData(1);
            this.uit.Data.event_count{this.plottedChannel}            = numel(index);
            
            this.applyIntervalThreshold();
            
            this.plotRecord();
            
        end
        
        
        
        function arrowButtonPushed(this,src)
            
            if strcmp( src.Text , '>') 
                this.tWindow = this.tWindow + this.windowSize;
            else
                this.tWindow = this.tWindow - this.windowSize;
            end
            this.plotRecord();
            
        end
        
        function channelSelecterDDChanged(this,src)
            
            if isempty(this.channelName)
                return
            end
            
            index = find( strcmp(src.Items,src.Value) == 1);
            this.plottedChannel = index;
            this.plotRecord();
            
        end
        
        function getPlotIndices(this)
            
            %determine full window (viewing is in center 1/3) and its pixel width
            this.firstTime = this.tWindow(1) - this.windowSize; 
            this.lastTime  = this.tWindow(2) + this.windowSize;
            this.width = get_axes_width(this.ax)*3;
            
            if this.lastTime < this.t(2) || this.firstTime > this.t(end-1)
                %only single point or less in range, return
                this.plotIndices = [];
                return;
            end
             
            %determine first and last time points of trace
            if this.firstTime < 0
                firstTraceTime = 0;
            else 
                firstTraceTime = this.firstTime;
            end
            
            if this.lastTime > this.t(end)
                lastTraceTime = this.t(end);
            else
                lastTraceTime = this.lastTime;
            end
            
            %determine t indices of those time points
            firstTraceIndex = round(firstTraceTime/(this.si))+1;
            if firstTraceIndex < 1
                firstTraceIndex = 1;
            end
            
            lastTraceIndex  = round(lastTraceTime/(this.si))+1;
            if lastTraceIndex > numel(this.t)
                lastTraceIndex = numel(this.t);
            end
            
            this.width = this.width * ( ( lastTraceTime - firstTraceTime ) / (this.lastTime - this.firstTime) );
            this.width = round(this.width);
            this.plotIndices = [firstTraceIndex lastTraceIndex];
            
        end
        
        function plotRecord(this)

            if isempty(this.filename) 
                %do nothing
                this.setLimits();
                return
            end
            
            this.getPlotIndices();
            this.thresholdLine.XData = [this.firstTime this.lastTime];
            
            if isempty(this.plotIndices) 
                %do nothing
                this.setLimits();
                return
            end
            
            %if no plots to plot, then return
            limits = [this.t(this.plotIndices(1)) this.t(this.plotIndices(2))];
            [this.tempX, this.tempY] = reduce_to_width(this.t(this.plotIndices(1):this.plotIndices(2)), this.record(this.plotIndices(1):this.plotIndices(2),this.plottedChannel), this.width,limits);
            this.plotter.XData = this.tempX;
            this.tempY = double(this.tempY)*(this.ADCScalingVoltage);
            this.plotter.YData = this.tempY; %10V over 32768 levels
            eventIndices = this.channelEvents(this.plottedChannel).eventIndex;
            eventsInWindowIndices = find(eventIndices >= this.plotIndices(1) & eventIndices <= this.plotIndices(2));
            eventIndices = eventIndices(eventsInWindowIndices);
            this.detectedPoints.XData = this.t(eventIndices);
            this.detectedPoints.YData = this.record(eventIndices,this.plottedChannel)*(this.ADCScalingVoltage);
            this.setLimits();
            
            
            
        end
        
        function setLimits(this)
            this.ax.XLim = [this.tWindow(1) this.tWindow(2)];
            
            if isempty(this.tempY)
                this.ax.YLim = [-Inf Inf];
                return
            end
            
            yAdd = 0.05*( max(this.tempY) - min(this.tempY) );
            this.ax.YLim = [(min(this.tempY)-yAdd) (max(this.tempY)+yAdd)];
        end
        
    end
    
    
end