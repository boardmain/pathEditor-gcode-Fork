class Editor {
	
	ControlP5 cp5;
	color bgColor = color(25);
	
	Numberbox widthControl, 
	          heightControl,
	          marginControl,
	          colsControl,
	          rowsControl,
	          penSizeControl,
	          numNoodlesControl,
	          thicknessControl,
			  minLengthControl,
       		  maxLengthControl,
			  marginOfPathControl,
			  numbersOfPathControl,
			  speedControl,
			  toolDownControl;
			  
			  
	ScrollableList paperSizeControl;

	Toggle twistControl,
	       joinControl,
	       overlapControl,
		   randomizeEndsControl,
		   roughLinesControl,
		   drawUnderLineControl,
		   exportGrupedControl,
		   useFillsControl;
	
	boolean controlsVisible = false;
		
	float printW;
	float printH;
	
	
	Editor(PApplet app) {
		cp5 = new ControlP5(app);
		PFont font = createFont("DIN", 12 / pixelDensity);
		cp5.setFont(font);
		
		paperSizeControl = cp5.addScrollableList("Paper Preset")
			.setPosition(200, 60)
			.setSize(100, 100)
			.setBarHeight(20)
			.setItemHeight(20)
			.addItems(new String[] {"A0", "A1", "A2", "A3", "A4", "A5", "Custom"})
			.setValue(4) // Default to A4, but will be updated in update()
			.setOpen(false)
			.setId(99)
			;

		widthControl = cp5.addNumberbox("Width (mm)")
			.setPosition(100,100)
			.setSize(100,20)
			.setRange(100.0,1000.0)
			.setMultiplier(1.0) // set the sensitifity of the numberbox
			.setDirection(Controller.HORIZONTAL) // change the control direction to left/right
			.setValue(PRINT_W_MM)
			.setDecimalPrecision(0)
			.setId(1)
			;
			
		heightControl = cp5.addNumberbox("Height (mm)")
			.setPosition(100,150)
			.setSize(100,20)
			.setRange(100.0, 1000.0)
			.setMultiplier(1.0) // set the sensitifity of the numberbox
			.setDirection(Controller.HORIZONTAL) // change the control direction to left/right
			.setValue(PRINT_H_MM)
			.setDecimalPrecision(0)
			.setId(2)
			;
		
		marginControl = cp5.addNumberbox("Margin (mm)")
			.setPosition(100,200)
			.setSize(100,20)
			.setRange(0.0,120.0)
			.setMultiplier(1.0) // set the sensitifity of the numberbox
			.setDirection(Controller.HORIZONTAL) // change the control direction to left/right
			.setValue(MARGIN_MM)
			.setDecimalPrecision(0)
			.setId(2)
			;

		colsControl = cp5.addNumberbox("Columns")
			.setPosition(100,275)
			.setSize(100,20)
			.setRange(1,400)
			.setMultiplier(1) // set the sensitifity of the numberbox
			.setDirection(Controller.HORIZONTAL) // change the control direction to left/right
			.setValue(GRID_W)
			.setDecimalPrecision(0)
			.setId(3)
			;
			
		rowsControl = cp5.addNumberbox("Rows")
			.setPosition(100,325)
			.setSize(100,20)
			.setRange(1,400)
			.setMultiplier(1) // set the sensitifity of the numberbox
			.setDirection(Controller.HORIZONTAL) // change the control direction to left/right
			.setValue(GRID_H)
			.setDecimalPrecision(0)
			.setId(4)
			;

		
		numNoodlesControl = cp5.addNumberbox("Noodles")
			.setPosition(100,400)
			.setSize(100,20)
			.setRange(1,800)
			.setMultiplier(1) // set the sensitifity of the numberbox
			.setDirection(Controller.HORIZONTAL) // change the control direction to left/right
			.setValue(penSizeMM)
			.setDecimalPrecision(0)
			.setId(6)
			;
		thicknessControl = cp5.addNumberbox("Thickness %")
			.setPosition(100,450)
			.setSize(100,20)
			.setRange(0.1,1.0)
			.setMultiplier(0.01) // set the sensitifity of the numberbox
			.setDirection(Controller.HORIZONTAL) // change the control direction to left/right
			.setValue(penSizeMM)
			.setDecimalPrecision(2)
			.setId(7)
			;

		minLengthControl = cp5.addNumberbox("Min Length")
			.setPosition(100,500)
			.setSize(100,20)
			.setRange(10,2000)
			.setMultiplier(1) // set the sensitifity of the numberbox
			.setDirection(Controller.HORIZONTAL) // change the control direction to left/right
			.setValue(penSizeMM)
			.setDecimalPrecision(0)
			.setId(8)
			;

		maxLengthControl = cp5.addNumberbox("Max Length")
			.setPosition(100,550)
			.setSize(100,20)
			.setRange(10,8000)
			.setMultiplier(1) // set the sensitifity of the numberbox
			.setDirection(Controller.HORIZONTAL) // change the control direction to left/right
			.setValue(penSizeMM)
			.setDecimalPrecision(0)
			.setId(9)
			;

		
		penSizeControl = cp5.addNumberbox("Pen Size")
			.setPosition(100,625)
			.setSize(100,20)
			.setRange(0.10,6)
			.setMultiplier(0.05) // set the sensitifity of the numberbox
			.setDirection(Controller.HORIZONTAL) // change the control direction to left/right
			.setValue(penSizeMM)
			.setDecimalPrecision(2)
			.setId(5)
			;

		numbersOfPathControl = cp5.addNumberbox("Numero Path")
			.setPosition(100,675)
			.setSize(100,20)
			.setRange(1,30)
			.setMultiplier(1) // set the sensitifity of the numberbox
			.setDirection(Controller.HORIZONTAL) // change the control direction to left/right
			.setValue(NUMBER_OF_PATHS)
			.setDecimalPrecision(0)
			.setId(10)
			;

		marginOfPathControl = cp5.addNumberbox("Margin Of Path")
			.setPosition(100,725)
			.setSize(100,20)
			.setRange(1,20)
			.setMultiplier(1) // set the sensitifity of the numberbox
			.setDirection(Controller.HORIZONTAL) // change the control direction to left/right
			.setValue(MARGIN_OF_PATH)
			.setDecimalPrecision(0)
			.setId(11)
			;

		speedControl = cp5.addNumberbox("Initial Speed")
			.setPosition(100,775)
			.setSize(100,20)
			.setRange(500,5000)
			.setMultiplier(100) // set the sensitifity of the numberbox
			.setDirection(Controller.HORIZONTAL) // change the control direction to left/right
			.setValue(TOOL_SPEED_MM_PER_MIN)
			.setDecimalPrecision(0)
			.setId(12)
			;

		toolDownControl = cp5.addNumberbox("Tool Down (mm)")
			.setPosition(100,825)
			.setSize(100,20)
			.setRange(2.0,10.0)
			.setMultiplier(0.1) // set the sensitifity of the numberbox
			.setDirection(Controller.HORIZONTAL) // change the control direction to left/right
			.setValue(TOOL_DOWN_MM)
			.setDecimalPrecision(1)
			.setId(13)
			;

		twistControl = cp5.addToggle("Use Twists")
			.setPosition(250,100)
			.setSize(20,20)
			.setValue(useTwists)
			;
		
		
		twistControl
			.getCaptionLabel()
			.align(ControlP5.RIGHT_OUTSIDE, ControlP5.CENTER)
			.setPaddingX(10)
			;
		
		joinControl = cp5.addToggle("Use Joins")
			.setPosition(250,150)
			.setSize(20,20)
			.setValue(useJoiners)
			;
		
		joinControl
			.getCaptionLabel()
			.align(ControlP5.RIGHT_OUTSIDE, ControlP5.CENTER)
			.setPaddingX(10)
			;
			
		overlapControl = cp5.addToggle("Allow Overlaps")
			.setPosition(250,200)
			.setSize(20,20)
			.setValue(allowOverlap)
			;
		
		overlapControl
			.getCaptionLabel()
			.align(ControlP5.RIGHT_OUTSIDE, ControlP5.CENTER)
			.setPaddingX(10)
			;

		randomizeEndsControl = cp5.addToggle("Randomize Ends")
			.setPosition(250,250)
			.setSize(20,20)
			.setValue(useCurves)
			;
		
		randomizeEndsControl
			.getCaptionLabel()
			.align(ControlP5.RIGHT_OUTSIDE, ControlP5.CENTER)
			.setPaddingX(10)
			;
		
		roughLinesControl = cp5.addToggle("Rough Lines")
			.setPosition(250,300)
			.setSize(20,20)
			.setValue(useRoughLines)
			;
		
		roughLinesControl
			.getCaptionLabel()
			.align(ControlP5.RIGHT_OUTSIDE, ControlP5.CENTER)
			.setPaddingX(10)
			;
			
		useFillsControl = cp5.addToggle("Use Fills")
			.setPosition(250,350)
			.setSize(20,20)
			.setValue(useRoughLines)
			;
		
		useFillsControl
			.getCaptionLabel()
			.align(ControlP5.RIGHT_OUTSIDE, ControlP5.CENTER)
			.setPaddingX(10)
			;
			
		drawUnderLineControl = cp5.addToggle("Draw Under Line")
			.setPosition(250,400)
			.setSize(20,20)
			.setValue(drawUnderLine)
			;
		
		drawUnderLineControl
			.getCaptionLabel()
			.align(ControlP5.RIGHT_OUTSIDE, ControlP5.CENTER)
			.setPaddingX(10)
			;

		exportGrupedControl = cp5.addToggle("Export Gruped")
			.setPosition(250,450)
			.setSize(20,20)
			.setValue(exportGrouped)
			;
		
		exportGrupedControl
			.getCaptionLabel()
			.align(ControlP5.RIGHT_OUTSIDE, ControlP5.CENTER)
			.setPaddingX(10)
			;
		
		hide();
	}

	void update() {
		widthControl.setValue(PRINT_W_MM);
		heightControl.setValue(PRINT_H_MM);
		marginControl.setValue(MARGIN_MM);
		colsControl.setValue(GRID_W);
		rowsControl.setValue(GRID_H);
		minLengthControl.setValue(minLength);
		maxLengthControl.setValue(maxLength);
		penSizeControl.setValue(penSizeMM);
		twistControl.setValue(useTwists);
		joinControl.setValue(useJoiners);
		overlapControl.setValue(useCurves);
		numNoodlesControl.setValue(numNoodles);
		thicknessControl.setValue(noodleThicknessPct);
		randomizeEndsControl.setValue(randomizeEnds);
		roughLinesControl.setValue(useRoughLines);
		useFillsControl.setValue(useFills);
		numbersOfPathControl.setValue(NUMBER_OF_PATHS);
		marginOfPathControl.setValue(MARGIN_OF_PATH);
		drawUnderLineControl.setValue(drawUnderLine);
		speedControl.setValue(TOOL_SPEED_MM_PER_MIN);
		toolDownControl.setValue(TOOL_DOWN_MM);
		exportGrupedControl.setValue(exportGrouped);
	}
	
	
	void show() {
		update();
		controlsVisible = true;
	}
	
	void hide() {
		PRINT_W_MM = widthControl.getValue();
		PRINT_H_MM = heightControl.getValue();
		NUMBER_OF_PATHS = int(numbersOfPathControl.getValue());
		MARGIN_OF_PATH = int(marginOfPathControl.getValue());
		TOOL_SPEED_MM_PER_MIN = int(speedControl.getValue());
		TOOL_DOWN_MM = toolDownControl.getValue();
		GRID_W = int(colsControl.getValue());
		GRID_H = int(rowsControl.getValue());
		penSizeMM = penSizeControl.getValue();
		strokeSize = calculateStrokeSize();

		useTwists = twistControl.getState();
		useJoiners = joinControl.getState();
		allowOverlap = overlapControl.getState();
		useRoughLines = roughLinesControl.getState();
		useFills = useFillsControl.getState();
		drawUnderLine = drawUnderLineControl.getState();
		exportGrouped = exportGrupedControl.getState();
		controlsVisible = false;
		cp5.hide();
		
	}
	
	void draw() {
		fill(50, 150);
		noStroke();
		rect(50, 50, 400, 850, 8);
		
		if(controlsVisible && !cp5.isVisible()){
			cp5.show();
		} 
	}

	boolean printSizeDidChange() {
		return (
			PRINT_W_MM != widthControl.getValue() || 
			PRINT_H_MM != heightControl.getValue() ||
			GRID_W != int(colsControl.getValue())||
			GRID_H != int(rowsControl.getValue()) ||
			NUMBER_OF_PATHS != int(numbersOfPathControl.getValue()) ||
			MARGIN_OF_PATH != int(marginOfPathControl.getValue()) ||
			MARGIN_MM != marginControl.getValue()
		);
	}
	
	void controlEvent(ControlEvent e) {
		if (e.getController().getName().equals("Paper Preset")) {
			int idx = (int)e.getValue();
			float w = -1, h = -1;
			// A0: 1189 x 841
			// A1: 841 x 594
			// A2: 594 x 420
			// A3: 420 x 297
			// A4: 297 x 210
			// A5: 210 x 148
			switch(idx) {
				case 0: w=1189; h=841; break; // A0
				case 1: w=841; h=594; break; // A1
				case 2: w=594; h=420; break; // A2
				case 3: w=420; h=297; break; // A3
				case 4: w=297; h=210; break; // A4
				case 5: w=210; h=148; break; // A5
				default: break; // Custom
			}
			if (w > 0 && h > 0) {
				widthControl.setValue(w);
				heightControl.setValue(h);
			}
		}

		if(controlsVisible){
			boolean updateSizes = printSizeDidChange();

			PRINT_W_MM = widthControl.getValue();
			PRINT_H_MM = heightControl.getValue();
			MARGIN_MM = marginControl.getValue();
			MARGIN_OF_PATH = int(marginOfPathControl.getValue());
			GRID_W = int(colsControl.getValue());
			GRID_H = int(rowsControl.getValue());
			penSizeMM = penSizeControl.getValue();
			strokeSize = calculateStrokeSize();
			minLength = int(minLengthControl.getValue());
			maxLength = int(maxLengthControl.getValue());
			NUMBER_OF_PATHS = int(numbersOfPathControl.getValue());
			TOOL_SPEED_MM_PER_MIN = int(speedControl.getValue());
			TOOL_DOWN_MM = toolDownControl.getValue();
			useTwists = twistControl.getState();
			useJoiners = joinControl.getState();
			allowOverlap = overlapControl.getState();
			numNoodles = int(numNoodlesControl.getValue());
			noodleThicknessPct = thicknessControl.getValue();
			randomizeEnds = randomizeEndsControl.getState();
			useRoughLines = roughLinesControl.getState();
			useFills = useFillsControl.getState();
			drawUnderLine = drawUnderLineControl.getState();
			exportGrouped = exportGrupedControl.getState();
			if(updateSizes){
				updateKeyDimensions();
			}
		}
		// println(" - got a control event from controller with id " + e.getId());
		// switch(theEvent.getId()) {
		// 	case(1): // numberboxA is registered with id 1
		// 		println((theEvent.getController().getValue()));
		// 	break;
		// 	case(2):  // numberboxB is registered with id 2
		// 		println((theEvent.getController().getValue()));
		// 	break;
		// }
	}
}

public void controlEvent(ControlEvent e) {
	// forward control events to Editor
	if(editor != null){
		editor.controlEvent(e);
	}
}
