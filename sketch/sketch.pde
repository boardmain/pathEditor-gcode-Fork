// Main sketch file

import controlP5.*;
import processing.svg.*;
import javax.swing.JOptionPane;
import java.util.HashSet;
import java.util.ArrayList;

Boolean USE_RETINA = true;

String SETTINGS_PATH = "config/settings.json";
String configPath = "config/config.json";
String TWIST_PATH = "graphics/twist.svg";
String TWIST_FILL_PATH = "graphics/twistFill.svg";

float MAX_SCREEN_SCALE = 0.182 * 2; // % - (0.2456 == macbook 1:1) (0.182 == LG Screen)
float SCREEN_SCALE = 0.182 * 2; 
float PRINT_W_MM = 297;
float PRINT_H_MM = 210;
int PRINT_RESOLUTION = 300;
float MARGIN_MM = 15;
int NUMBER_OF_PATHS = 1;
int MARGIN_OF_PATH = 10;
// float MAT_W_MM = 273; // Unused
// float MAT_H_MM = 349; // Unused
float TOOL_DOWN_MM = 5.2;
float TOOL_UP_MM = 0.0;
int TOOL_SPEED_MM_PER_MIN = 2000;

int TILE_SIZE = 50;
int GRID_W = 11;
int GRID_H = 11;

int PRINT_X = 0;
int PRINT_Y = 0;

int canvasW = int(PRINT_W_MM / 25.4 * PRINT_RESOLUTION * SCREEN_SCALE);
int canvasH = int(PRINT_H_MM / 25.4 * PRINT_RESOLUTION * SCREEN_SCALE);

int canvasX = 0;
int canvasY = 0;

boolean EDIT_MODE = false;
boolean BLACKOUT_MODE = false;
boolean CELLTYPE_MODE = false;
boolean PATH_EDIT_MODE = false;
boolean GROUP_SELECT_MODE = false;

int editingNoodle = 0;
int[][] blackoutCells;
int[][] cellGroups;
ArrayList<Integer> exportGroupQueue = new ArrayList<Integer>();
ArrayList<String> filesToConvert = new ArrayList<String>();
Process currentConversionProcess = null;
int currentExportGroup = 0;
String exportBaseName = "";
boolean autoConvertGroups = false;

boolean saveFile = false;
boolean autoConvertGcode = false;
boolean useSmartFill = false;

Noodle noodle; 
Noodle noodle2;

int numNoodles = 3;
Noodle[] noodles;

PShape twist;
PShape twistFill;

Point[][] paths;
int[][] cells;

// SETTINGS
boolean showGrid = false;
boolean useTwists = true;
boolean useJoiners = true;
boolean useCurves = true;
float penSizeMM = 0.35;
float strokeSize = calculateStrokeSize();
float noodleThicknessPct = 0.5;
GraphicSet[] graphicSets;
boolean randomizeEnds = false;
boolean allowOverlap = true;
boolean showInfoPanel = false;
boolean useRoughLines = false;
boolean useFills = true;
boolean reduceCurveSpeed = false;

int minLength = 200;
int maxLength = 1000;

ImageSaver imgSaver = new ImageSaver();
String fileNameToSave = "";

Editor editor;


boolean shiftIsDown = false;


PFont menloFont;

void settings() {
	
	// size(displayWidth, displayHeight - 45);
	//size(1920, 1080);
	fullScreen();
	if(USE_RETINA){
		pixelDensity(displayDensity());
	}
}

void setup() {
	editor = new Editor(this);
	frameRate(12);
	menloFont = createFont("Menlo", 12);

	loadSettings(SETTINGS_PATH);
	loadConfigFile(configPath, "");

	twist = loadShape(TWIST_PATH);
	twist.disableStyle();
	twistFill = loadShape(TWIST_FILL_PATH);
	twistFill.disableStyle();
	
	colorMode(HSB, 360, 100, 100);
	reset();
}


float calculateStrokeSize() {
	float size = (penSizeMM * 0.03937008) * PRINT_RESOLUTION * SCREEN_SCALE; 
	return size;
}

void calculateScreenScale() {
	float maxW = width - 100;
	float maxH = height - 100;
	
	float printW = (PRINT_W_MM / 25.4) * PRINT_RESOLUTION;
	float printH = (PRINT_H_MM / 25.4) * PRINT_RESOLUTION;
	SCREEN_SCALE = maxW / printW;
	
	if(printH * SCREEN_SCALE > maxH){
		SCREEN_SCALE = maxH / printH;
	}
	
	if(SCREEN_SCALE > MAX_SCREEN_SCALE){
		SCREEN_SCALE = MAX_SCREEN_SCALE;
	}
	
	canvasW = int((PRINT_W_MM / 25.4) * PRINT_RESOLUTION * SCREEN_SCALE);
	canvasH = int((PRINT_H_MM / 25.4) * PRINT_RESOLUTION * SCREEN_SCALE);
	
	canvasX = (width - canvasW) /2;
	canvasY = (height - canvasH) /2;
}

void calculateTileSize() {
	int marginPx = int((MARGIN_MM / 25.4) * PRINT_RESOLUTION * SCREEN_SCALE);
	int printAreaW = canvasW - marginPx * 2;
	int printAreaH = canvasH - marginPx * 2;
	TILE_SIZE = printAreaW / GRID_W;
	
	if(GRID_H * TILE_SIZE > printAreaH){
		TILE_SIZE = printAreaH / GRID_H;
	}
	
	// tile size must be even
	TILE_SIZE = (TILE_SIZE / 2) * 2;
	
	PRINT_X =  (canvasW - (TILE_SIZE * GRID_W)) / 2;
	PRINT_Y = (canvasH - (TILE_SIZE * GRID_H)) / 2;
}

color paperColor = color(255);
void drawPaperBG() {
	fill(paperColor);
	stroke(80);
	strokeWeight(1);
	rect(canvasX, canvasY, canvasW, canvasH);
}

void drawBG() {
	background(100);
	if(imgSaver.isBusy()){ drawSaveIndicator();}
	drawPaperBG();
	
}

void draw() {
	colorMode(RGB, 255,255,255);
	
	// Handle Export and Conversion Queue
    if (imgSaver.state == SaveState.NONE) {
        // 1. Finish current group if one was processing
        if (currentExportGroup > 0) {
            println("Export complete for group " + currentExportGroup);
            if (autoConvertGroups) {
                filesToConvert.add("output/" + fileNameToSave + ".svg");
            }
            currentExportGroup = 0;
        }

        // 2. Start next group SVG creation if available
        if (exportGroupQueue.size() > 0) {
            int grp = exportGroupQueue.remove(0);
            currentExportGroup = grp;
            fileNameToSave = exportBaseName + "_group_" + grp;
            
            int _plotW = int((PRINT_W_MM / 25.4) * PRINT_RESOLUTION * SCREEN_SCALE);
            int _plotH = int((PRINT_H_MM / 25.4) * PRINT_RESOLUTION * SCREEN_SCALE);
            if(USE_RETINA){
                _plotW = _plotW * 2;
                _plotH = _plotH * 2;
            }
            imgSaver.begin(PRINT_W_MM, PRINT_H_MM, _plotW, _plotH, fileNameToSave);
            println("Starting export for group " + grp);
        }
        
        // 3. Process GCode Conversion Queue (only if SVG export is done)
        else if (autoConvertGroups && (filesToConvert.size() > 0 || currentConversionProcess != null)) {
            
            if (currentConversionProcess != null) {
                // Check if process is still running
                 try {
                     // exitValue throws exception if process is not finished
                    int exitVal = currentConversionProcess.exitValue();
                    println("Conversion process finished with exit code: " + exitVal);
                    currentConversionProcess = null;
                } catch (IllegalThreadStateException e) {
                    // Process is still running, do nothing
                }
            }
            
            if (currentConversionProcess == null && filesToConvert.size() > 0) {
                String nextFile = filesToConvert.remove(0);
                println("Starting conversion for: " + nextFile);
                currentConversionProcess = runSvgToGcodeProcess(nextFile);
            }
        }
        
        else if (autoConvertGroups && exportGroupQueue.isEmpty() && filesToConvert.isEmpty() && currentConversionProcess == null && currentExportGroup == 0) {
             println("All batch operations completed.");
             autoConvertGroups = false;
        }
    }
	
	pushMatrix();
		drawBG();
		if(showInfoPanel) drawInfoPanel();
		
		translate(canvasX, canvasY);
		if(imgSaver.state == SaveState.SAVING){
			beginRecord(SVG, "output/" + fileNameToSave + ".svg");
		}

		translate(PRINT_X, PRINT_Y);
		if(showGrid){ drawGrid();}
		
		colorMode(HSB, 360, 100, 100);

        // Draw registration marks if exporting a group to ensure alignment
        if (currentExportGroup > 0) {
            drawRegistrationMarks();
        }

		for(int i=0; i < noodles.length; i++){
			if(noodles[i] != null){
				int pathIndex = i % NUMBER_OF_PATHS;
				
				// Calcoliamo la nuova percentuale di spessore basata sull'indice e sul MARGIN_OF_PATH
				// Spessore originale in pixel
				float baseThickness = TILE_SIZE * noodleThicknessPct;
				// Riduzione: ogni step verso l'interno riduce lo spessore di (2 * MARGIN)
				// pathIndex 0 (esterno) -> riduzione 0
				// pathIndex 1 -> riduzione 2 * MARGIN
				float reduction = pathIndex * 2 * MARGIN_OF_PATH;
				float currentThickness = baseThickness - reduction;
				
				// Se lo spessore diventa troppo sottile (inferiore al margine), 
				// lo collassiamo a una singola linea centrale (spessore 0)
				if(currentThickness < MARGIN_OF_PATH && currentThickness > -MARGIN_OF_PATH){ 
					// Usiamo un range negativo piccolo per catturare il caso in cui 
					// la riduzione supera di poco lo spessore, se vogliamo un comportamento "graceful",
					// ma la richiesta specifica "più vicine del valore MARGIN_OF_PATH".
					// Se le linee sono distanti meno di MARGIN_OF_PATH, collassa.
					currentThickness = 0;
				}

				// Se lo spessore è valido (>= 0), disegniamo
				// Nota: >= 0 permette di disegnare la linea singola (thickness 0)
				if(currentThickness >= 0){
					float currentPct = currentThickness / (float)TILE_SIZE;
					noodles[i].draw(TILE_SIZE, currentPct, useTwists, currentExportGroup);
				}
			}
		}	
		
		
		if(imgSaver.state == SaveState.SAVING) { endRecord(); }
		imgSaver.update();

		if(autoConvertGcode && imgSaver.state == SaveState.COMPLETE) {
			String svgPath = "output/" + fileNameToSave + ".svg";
			runSvgToGcode(svgPath);
			autoConvertGcode = false;
		}
	popMatrix();
	if(EDIT_MODE) {
		editor.draw();
	} 
}

void runSvgToGcode(String svgPath) {
    runSvgToGcodeProcess(svgPath);
}

Process runSvgToGcodeProcess(String svgPath) {
	String scriptPath = sketchPath("svg2gcode.sh");
	String absSvgPath = sketchPath(svgPath);
	
	String[] cmd = {
		scriptPath,
		absSvgPath,
		str(TOOL_UP_MM),
		str(TOOL_DOWN_MM),
		str(TOOL_SPEED_MM_PER_MIN),
		str(PRINT_W_MM),
		str(PRINT_H_MM),
		str(MARGIN_MM)
	};
	
	println("Executing conversion: " + join(cmd, " "));
	try {
        // exec returns a Process object
		return exec(cmd);
	} catch (Exception e) {
		e.printStackTrace();
        return null;
	}
}

void drawRegistrationMarks() {
    pushMatrix();
    noFill();
    stroke(0); // Black marks
    
    // Calculate mark size relative to tile size or fixed
    float markSize = 4; // Small enough to be filtered (< 2mm usually) but visible for bounding box
    // 2mm is roughly 6-8 pixels at 96dpi, or depending on scale.
    // If we filter < 2mm in vpype:
    // We need markSize to constitute a line length < 2mm.
    // Let's make individual legs of the mark 1.5mm approx?
    // PRINT_RESOLUTION is 300. 1mm = 11.8 px.
    // So 2mm is ~23px.
    // markSize = 10 px is < 1mm. Safe to filter with --min-length 2mm.
    markSize = 10; 
    
    strokeWeight(1); 

    // Top-Left
    line(0, 0, markSize, 0);
    line(0, 0, 0, markSize);
    
    // Top-Right
    float w = GRID_W * TILE_SIZE;
    line(w, 0, w - markSize, 0);
    line(w, 0, w, markSize);
    
    // Bottom-Left
    float h = GRID_H * TILE_SIZE;
    line(0, h, 0, h - markSize);
    line(0, h, markSize, h);
    
    // Bottom-Right
    line(w, h, w - markSize, h);
    line(w, h, w, h - markSize);
    
    // Center Cross for extra alignment help? Optional, but user asked for "alignment marks"
    // line(w/2 - markSize, h/2, w/2 + markSize, h/2);
    // line(w/2, h/2 - markSize, w/2, h/2 + markSize);
    
    popMatrix();
}

int[][] copyBlackoutCells() {
	int[][] cells = new int[GRID_W][GRID_H];
	for(int col = 0; col < GRID_W; col++){
		cells[col] = new int[GRID_H];
		for(int row = 0; row < GRID_H; row++){
			if(blackoutCells[col][row] > 0){
				cells[col][row] = CellType.BLACKOUT;
			}
		}
	}
	return cells;
}

void updateBlackoutCells() {
	if(blackoutCells == null || GRID_W != blackoutCells.length || GRID_H != blackoutCells[0].length){
		blackoutCells = new int[GRID_W][GRID_H];
	}
}

void updateCellGroups() {
	if(cellGroups == null || GRID_W != cellGroups.length || GRID_H != cellGroups[0].length){
		cellGroups = new int[GRID_W][GRID_H];
	}
}

void updateKeyDimensions() {
	updateBlackoutCells();
	updateCellGroups();
	calculateScreenScale();
	calculateTileSize();
	strokeSize = calculateStrokeSize();
}

color getColorForCellType(int cellType) {
	color[] colors = { 
		color(0, 5),
		color(0, 255, 0, 100),
		color(0, 0, 255, 100),

		color(255, 0, 0, 100),
		color(255, 0, 0, 100),
		color(255, 0, 0, 100),
		color(255, 0, 0, 100),

		color(255, 255, 0, 100),
		color(255, 255, 0, 100),

		color(0),
		color(0),

		color(255, 0, 255, 100)};

	return colors[cellType];
}

color getColorForGroup(int groupId) {
	if (groupId <= 0) return color(0, 0);
	// Generate a color based on group ID
	float r = (groupId * 123456) % 255;
	float g = (groupId * 654321) % 255;
	float b = (groupId * 321654) % 255;
	return color(r, g, b, 150);
}

void reset() {
	updateKeyDimensions();

	cells = copyBlackoutCells();
	noodles = new Noodle[numNoodles * NUMBER_OF_PATHS];
	
	int hueRange = 200;//floor(random(0, 310));
	// int sat = floor(random(60, 80));
	// int brt = floor(random(80, 100));
	
	int noodleCount = 0;
	for(int i=0; i < numNoodles; i++){
		Point[] p = null;
    if (useSmartFill) {
      p = createSmartPath(cells);
    } else {
      p = createNoodlePath(cells);
    }
		
		if(p != null){
			int graphicIndex = floor(random(0, graphicSets.length));
			GraphicSet gfx = graphicSets[graphicIndex];
			PShape head = gfx.head;
			PShape tail = gfx.tail;

			if(randomizeEnds){
				int tailIndex = floor(random(0, graphicSets.length));
				tail = graphicSets[tailIndex].head;
			}
			
			
			int hue = floor(random(hueRange, hueRange + 50));
			// int hue = (hueRange + noodleCount * 3) % 360;
			int sat = 70; //floor(random(60, 80));
			int brt = 90; //floor(random(80, 100));
			color fillColor = color(hue, sat, brt);
			
			for(int j=0; j < NUMBER_OF_PATHS; j++){
				noodles[noodleCount] = new Noodle(p, TILE_SIZE, head, tail, gfx.joiners, twist, twistFill, fillColor, millis());
				noodleCount++;
			}
		}
	}
	
	noodles = (Noodle[]) subset(noodles, 0, noodleCount);
}

void deleteNoodle(int indexToDelete) {
	if(noodles.length <= 1) return; // don't delete all the noodles

	Noodle[] updatedNoodles = new Noodle[noodles.length - 1];
	int fillIndex = 0;
	for(int i = 0; i < noodles.length; i++){
		if(i != indexToDelete){
			updatedNoodles[fillIndex] = noodles[i];
			fillIndex++;
		}
	}
	noodles = updatedNoodles;
	editingNoodle = min(editingNoodle, noodles.length - 1);
	
}

void keyReleased() {
	if(keyCode == SHIFT){
		shiftIsDown = false;
	}
}

void keyPressed() {
	switch(keyCode){
		case SHIFT:
			shiftIsDown = true;
		break;
		case BACKSPACE:
			if(PATH_EDIT_MODE){
				deleteNoodle(editingNoodle);
			}
		break;
	}
	switch(key) {
		case 'q':
			generateAllGcodes();
		break;
		case 's' :
			fileNameToSave = getFileName();
			int _plotW = int((PRINT_W_MM / 25.4) * PRINT_RESOLUTION * SCREEN_SCALE);
			int _plotH = int((PRINT_H_MM / 25.4) * PRINT_RESOLUTION * SCREEN_SCALE);
			if(USE_RETINA){
				_plotW = _plotW * 2;
				_plotH = _plotH * 2;
			}

			imgSaver.begin(PRINT_W_MM, PRINT_H_MM, _plotW, _plotH, fileNameToSave);
		break;
		case 'g':
			showGrid = !showGrid;
			if(!showGrid){
				BLACKOUT_MODE = false;
				PATH_EDIT_MODE = false;
			}
		break;
		case 'r':
			reset();
		break;
		case 't':
			TILE_SIZE++;
		break;
		case 'e':
			EDIT_MODE = !EDIT_MODE;
			if(EDIT_MODE){
				editor.show();
			} else {
				editor.hide();
				// reset();
			}
		break;
		case 'x':
			BLACKOUT_MODE = !BLACKOUT_MODE;
			if(BLACKOUT_MODE){
				showGrid = true;
			}
		break;
		case 'p' :
			PATH_EDIT_MODE = !PATH_EDIT_MODE;
			if(PATH_EDIT_MODE){
				showGrid = true;
			}
		break;
		case 'l' :
			selectConfigFile();
		break;

		case 'c' :
			CELLTYPE_MODE = !CELLTYPE_MODE;
			break;
		case 'w' :
		case 'W' :
			GROUP_SELECT_MODE = !GROUP_SELECT_MODE;
			if(GROUP_SELECT_MODE){
				showGrid = true;
			}
			break;
		case 'u':
		case 'U':
			importImageShape();
			break;
		case 'i' :
			importMaskImage();
			break;
		case 'I' :
			if(maskImage != null){
				processMaskData();
			} else {
				importMaskImage();
			}
			break;
		case 'h':
		case 'H':
			if (cellGroups != null) {
				for(int col = 0; col < cellGroups.length; col++){
					for(int row = 0; row < cellGroups[col].length; row++){
						cellGroups[col][row] = 0;
					}
				}
				println("Group selections cleared");
			}
			break;
		case 'k':
        case 'K':
        case 'j':
        case 'J':
			// Start Group Export
			if (cellGroups == null) {
				println("No groups defined.");
				break;
			}
            
            // Set conversion flag based on key
            autoConvertGroups = (key == 'j' || key == 'J');
            filesToConvert.clear(); // Clear pending conversions

			HashSet<Integer> uniqueGroups = new HashSet<Integer>();
			for (int col = 0; col < cellGroups.length; col++) {
				for (int row = 0; row < cellGroups[col].length; row++) {
					if (cellGroups[col][row] > 0) {
						uniqueGroups.add(cellGroups[col][row]);
					}
				}
			}
			
			if (uniqueGroups.isEmpty()) {
				println("No groups found to export.");
			} else {
				exportGroupQueue.clear();
				exportGroupQueue.addAll(uniqueGroups);
				// Sort to export in order 1, 2, 3...
				java.util.Collections.sort(exportGroupQueue);
				
				exportBaseName = getFileName();
				println("Starting export for groups: " + exportGroupQueue);
			}
			break;
	}
}

void mouseDragged() {
	
	if(BLACKOUT_MODE){
		Point cell = getCellForMouse(mouseX, mouseY);
		if(cell.x >= 0 && cell.y >= 0 && cell.x < blackoutCells.length && cell.y < blackoutCells[0].length){
			if(isDrawing){
				blackoutCells[cell.x][cell.y] = CellType.BLACKOUT;
			} else {
				blackoutCells[cell.x][cell.y] = 0;
			}
		} 
	}
}

boolean isDrawing = true;
void mousePressed() {
	Point cell = getCellForMouse(mouseX, mouseY);

	if(BLACKOUT_MODE){
		if(cell.x >= 0 && cell.y >= 0 && cell.x < blackoutCells.length && cell.y < blackoutCells[0].length){
			if(blackoutCells[cell.x][cell.y] > 0){
				isDrawing = false;
				blackoutCells[cell.x][cell.y] = 0;
			} else {
				isDrawing = true;
				blackoutCells[cell.x][cell.y] = CellType.BLACKOUT;
			}
		} 
	} else if (GROUP_SELECT_MODE) {
		if(cell.x >= 0 && cell.y >= 0 && cellGroups != null && cell.x < cellGroups.length && cell.y < cellGroups[0].length){
			String input = JOptionPane.showInputDialog("Enter group number (0 to clear):", str(cellGroups[cell.x][cell.y]));
			if (input != null) {
				try {
					int group = int(input);
					cellGroups[cell.x][cell.y] = group;
				} catch (Exception e) {
					println("Invalid input");
				}
			}
		}
	} else if(PATH_EDIT_MODE){
		if(shiftIsDown){
			editingNoodle = findNoodleWithCell(cell.x, cell.y);
		} else {
			if(pathContainsCell(noodles[editingNoodle].path, cell.x, cell.y)){
				if(cellIsEndOfPath(cell.x, cell.y, noodles[editingNoodle].path)){
					Point[] newPath = removeCellFromPath(cell.x, cell.y, noodles[editingNoodle].path);
					noodles[editingNoodle].path = newPath;
				} else {
					Point[] newPath = cycleCellType(cell.x, cell.y, noodles[editingNoodle].path);
					noodles[editingNoodle].path = newPath;
				}
			} else {
				Point[] newPath = addCellToPath(cell.x, cell.y, noodles[editingNoodle].path);
				noodles[editingNoodle].path = newPath;
			}
		}
	}
}

void drawSaveIndicator() {
	pushMatrix();
		fill(color(200, 0, 0));
		noStroke();
		rect(0,0,width, 4);
	popMatrix();
}

boolean pathContainsCell(Point[] path, int col, int row) {
	for(Point p : path){

		if(p != null && p.x == col && p.y == row){
			return true;
		}
	}

	return false;
}

void drawCellTypes() {
	pushMatrix();
	noFill();
	stroke(200);
	strokeWeight(1);
	for(int row = 0; row < GRID_H; row++){
		for(int col = 0; col < GRID_W; col++){
			if(BLACKOUT_MODE && blackoutCells[col][row] > 0){
				fill(0,25);
			} else if(PATH_EDIT_MODE && pathContainsCell(noodles[editingNoodle].path, col, row)) {
				fill(0, 255, 0, 25);
			} else if(CELLTYPE_MODE){
				fill(getColorForCellType(cells[col][row]));
			} else if(GROUP_SELECT_MODE && cellGroups[col][row] > 0){
				fill(getColorForGroup(cellGroups[col][row]));
			} else {
				noFill();
			}
			rect(col * TILE_SIZE, row * TILE_SIZE, TILE_SIZE, TILE_SIZE);
			
			if(GROUP_SELECT_MODE && cellGroups[col][row] > 0){
				fill(0);
				textAlign(CENTER, CENTER);
				textSize(TILE_SIZE/3);
				text(str(cellGroups[col][row]), col * TILE_SIZE + TILE_SIZE/2, row * TILE_SIZE + TILE_SIZE/2);
			}
		}
	}
	popMatrix();
}
void drawGridLines() {
	pushMatrix();
	stroke(200);
	strokeWeight(1);
	for(int row = 0; row <= GRID_H; row++){
		line(0, row * TILE_SIZE, GRID_W * TILE_SIZE, row * TILE_SIZE);
	}

	for(int col = 0; col <= GRID_W; col++){
		line(col * TILE_SIZE, 0, col * TILE_SIZE, GRID_H * TILE_SIZE);
	}
	popMatrix();
}

void drawGrid() {

	if(BLACKOUT_MODE || PATH_EDIT_MODE || CELLTYPE_MODE || GROUP_SELECT_MODE){
		if(imgSaver.state != SaveState.SAVING){
			drawCellTypes();
		}
	} 
	
	drawGridLines();

	// if(mask != null){
	// 	image(mask, 0, 0);
	// }
}

String getFileName() {
	String d  = str( day()    );  // Values from 1 - 31
	String mo = str( month()  );  // Values from 1 - 12
	String y  = str( year()   );  // 2003, 2004, 2005, etc.
	String s  = str( second() );  // Values from 0 - 59
 	String min= str( minute() );  // Values from 0 - 59
 	String h  = str( hour()   );  // Values from 0 - 23

 	String date = y + "-" + mo + "-" + d + " " + h + "-" + min + "-" + s;
 	String n = date;
 	return n;
}

void generateAllGcodes() {
	println("Triggering " + getFileName() + " SVG Save & G-code Conversion...");
	
	fileNameToSave = getFileName();
	int _plotW = int((PRINT_W_MM / 25.4) * PRINT_RESOLUTION * SCREEN_SCALE);
	int _plotH = int((PRINT_H_MM / 25.4) * PRINT_RESOLUTION * SCREEN_SCALE);
	if(USE_RETINA){
		_plotW = _plotW * 2;
		_plotH = _plotH * 2;
	}

	imgSaver.begin(PRINT_W_MM, PRINT_H_MM, _plotW, _plotH, fileNameToSave);
	autoConvertGcode = true;
}
