class Noodle {
	float margin = 0;
	float thickness = 10;
	float thicknessPct = 0.5;
	int tileSize = 0;
	
	int headWidth = 100;
	int seed = 0;
	
	Point[] path;
	
	PShape head, tail;
	PShape[] joiners;
	PShape twist;
	PShape twistFill;
	color fillColor;
	
	void calculateSizes(int tileW, float pct) {
		tileSize = tileW;
		thicknessPct = pct;
		thickness = (float)tileSize * thicknessPct;
		
		margin = (tileSize - thickness) / 2.0;
	}

	Noodle(Point[] p, int tileW, PShape h, PShape t, PShape[] j, PShape tw, PShape twf,color fc, int rs) {
		calculateSizes(tileW, thicknessPct);
		head = h;
		tail = t;
		
		joiners = j;
		twist = tw;
		twistFill = twf;
		path = p;
		fillColor = fc;

		seed = rs;
	}

	
	void drawEnd(boolean isFill, Point pos, Point neighbor) {
		pushMatrix();
		translate(tileSize / 2, tileSize/2);
		
		if(neighbor.x < pos.x){ // neighbor Left
			rotate(HALF_PI); // +Y becomes -X (Left). Connect Down.
		} else if(neighbor.x > pos.x){ // neighbor Right
			rotate(-HALF_PI); // +Y becomes +X (Right). Connect Down.
		} else if(neighbor.y < pos.y){ // neighbor Top
			rotate(PI); // +Y becomes -Y (Top). Connect Down.
		}
		// else neighbor Bottom. Connect Down (+Y).
		
		if(isFill){
			// Draw filled semi-circle cap + straight connection
			noStroke();
			// Straight part: from center (0,0) to edge (0, tileSize/2)
			rect(-thickness/2, 0, thickness, tileSize/2);
			// Cap part: semi-circle at top
			arc(0, 0, thickness, thickness, PI, TWO_PI);
		} else {
			// Draw outline
			noFill();
			// Straight lines
			line(-thickness/2, 0, -thickness/2, tileSize/2);
			line(thickness/2, 0, thickness/2, tileSize/2);
			// Cap arc
			arc(0, 0, thickness, thickness, PI, TWO_PI);
		}
		
		popMatrix();
	}
	
	void verticalShape(PShape shape){
		verticalShape(shape, false);
	}

	void verticalShape(PShape shape, boolean isFill) {
		float scale = (float)thickness / (float)headWidth;
		float distToGfx = (tileSize - headWidth * scale)/2;
		
		if(isFill){
			rect(margin, 0, tileSize - margin * 2, distToGfx);
			rect(margin, tileSize - distToGfx, tileSize - margin * 2, distToGfx);
		} else {
			line(margin, 0, margin, distToGfx);
			line(tileSize - margin, 0, tileSize - margin, distToGfx);
			line(margin, tileSize - distToGfx, margin, tileSize);
			line(tileSize - margin, tileSize - distToGfx, tileSize-margin, tileSize);
		}
		
		pushMatrix();
			translate(tileSize / 2, tileSize/2);
			scale(scale);
			strokeWeight(strokeSize / scale);
			shape(shape, headWidth/-2 , headWidth/-2);
			strokeWeight(strokeSize);
		popMatrix();
	}

	void verticalTwist(boolean isFill) {
		if(isFill){
			verticalShape(twistFill, true);
		} else {
			verticalShape(twist);
		}
	}
	
	void verticalJoin(int type) {
		verticalShape(joiners[type -1]);
	}

	void horizontalShape(PShape shape) {
		horizontalShape(shape, false);
	}

	void horizontalShape(PShape shape, boolean isFill) {
		float scale = (float)thickness / (float)headWidth;
		float distToGfx = (tileSize - headWidth * scale)/2;
		
		if(isFill){
			rect(0, margin, distToGfx, tileSize - margin * 2);
			rect(tileSize - distToGfx, margin, distToGfx, tileSize - margin * 2);
		} else {
		
			line(0, margin, distToGfx, margin);
			line( 0,tileSize - margin,  distToGfx, tileSize - margin);
			line(tileSize - distToGfx, margin,  tileSize, margin );
			line(tileSize - distToGfx, tileSize - margin,  tileSize, tileSize-margin);
		}
		
		pushMatrix();
			translate(tileSize / 2, tileSize/2);
			scale(scale);
			rotate(HALF_PI);
			strokeWeight(strokeSize / scale);
			shape(shape, headWidth/-2 , headWidth/-2);
			strokeWeight(strokeSize);
		popMatrix();
	}

	void horizontalTwist(boolean isFill) {
		if(isFill){
			horizontalShape(twistFill, true);
		} else {
			horizontalShape(twist);
		}
	}
	
	void writeGcode(float startX, float startY, float ts_mm, float thick_mm) {
		float marg_mm = (ts_mm - thick_mm) / 2.0;
		// If thickness is ~0 (collapsed), we treat it as single line (marg = ts/2).
		boolean isCollapsed = (thick_mm < 0.1); 
		
		PMatrix2D m = new PMatrix2D();
		
		// PASS 1: LEFT WALL (Forward)
		// Or Center Line if collapsed.
		for(int i = 0; i < path.length; i++) {
			Point p = path[i];
			m.reset();
			m.translate(startX + p.x * ts_mm, startY + p.y * ts_mm);
			
			Point prev = (i > 0) ? path[i-1] : null;
			Point next = (i < path.length - 1) ? path[i+1] : null;
			
			boolean top = false, right = false, bottom = false, left = false;
			float rotation = 0;
			
			if (i == 0) {
				// HEAD
				Point neighbor = path[i+1];
				if(neighbor.x < p.x) { rotation = HALF_PI; }
				else if(neighbor.x > p.x) { rotation = -HALF_PI; }
				else if(neighbor.y < p.y) { rotation = PI; }
				else { rotation = 0; }
				
				m.rotate(rotation);
				if(!isCollapsed) {
					drawHeadCapGcode(m, ts_mm, marg_mm, thick_mm, true);
				} else {
					// Collapsed Head: Single Line from Center to Bottom Edge.
					// Center (t/2, t/2) -> Bottom (t/2, t)
					addLine(m, ts_mm/2.0, ts_mm/2.0, ts_mm/2.0, ts_mm);
				}
			} else if (i == path.length - 1) {
				// TAIL
				Point neighbor = path[i-1];
				if(neighbor.x < p.x) { rotation = HALF_PI; }
				else if(neighbor.x > p.x) { rotation = -HALF_PI; }
				else if(neighbor.y < p.y) { rotation = PI; }
				else { rotation = 0; } // neighbor is below
				
				m.rotate(rotation);
				if(!isCollapsed){
					drawTailCapGcode(m, ts_mm, marg_mm, thick_mm, true);
				} else {
					// Collapsed Tail: Single Line from Bottom Edge to Center.
					// Bottom (t/2, t) -> Center (t/2, t/2)
					addLine(m, ts_mm/2.0, ts_mm, ts_mm/2.0, ts_mm/2.0);
				}
			} else {
				// BODY
				top = (prev.y < p.y || next.y < p.y);
				bottom = (prev.y > p.y || next.y > p.y);
				left = (prev.x < p.x || next.x < p.x);
				right = (prev.x > p.x || next.x > p.x);
				
				if (top && bottom) {
					drawVerticalGcode(m, ts_mm, marg_mm, thick_mm, true);
				} else if (left && right) {
					m.rotate(HALF_PI);
					drawVerticalGcode(m, ts_mm, marg_mm, thick_mm, true);
				} else if (bottom && right) {
					drawCornerTLGcode(m, ts_mm, marg_mm, thick_mm, true);
				} else if (bottom && left) {
					drawCornerTRGcode(m, ts_mm, marg_mm, thick_mm, true);
				} else if (top && left) {
					drawCornerBRGcode(m, ts_mm, marg_mm, thick_mm, true);
				} else if (top && right) {
					drawCornerBLGcode(m, ts_mm, marg_mm, thick_mm, true);
				}
			}
		}
		
		if(isCollapsed) return; // Stop here if single line mode.
		
		// PASS 2: RIGHT WALL (Backward)
		for(int i = path.length - 1; i >= 0; i--){
			Point p = path[i];
			m.reset();
			m.translate(startX + p.x * ts_mm, startY + p.y * ts_mm);
			
			Point prev = (i > 0) ? path[i-1] : null;
			Point next = (i < path.length - 1) ? path[i+1] : null;
			
			boolean top = false, right = false, bottom = false, left = false;
			float rotation = 0;
			
			if (i == 0) {
				// HEAD (Right side now)
				Point neighbor = path[i+1];
				if(neighbor.x < p.x) { rotation = HALF_PI; }
				else if(neighbor.x > p.x) { rotation = -HALF_PI; }
				else if(neighbor.y < p.y) { rotation = PI; }
				else { rotation = 0; }
				
				m.rotate(rotation);
				drawHeadCapGcode(m, ts_mm, marg_mm, thick_mm, false); // false = Right
			} else if (i == path.length - 1) {
				// TAIL (Right side now)
				Point neighbor = path[i-1];
				if(neighbor.x < p.x) { rotation = HALF_PI; }
				else if(neighbor.x > p.x) { rotation = -HALF_PI; }
				else if(neighbor.y < p.y) { rotation = PI; }
				else { rotation = 0; }
				
				m.rotate(rotation);
				drawTailCapGcode(m, ts_mm, marg_mm, thick_mm, false); // false = Right
			} else {
				// BODY
				top = (prev.y < p.y || next.y < p.y);
				bottom = (prev.y > p.y || next.y > p.y);
				left = (prev.x < p.x || next.x < p.x);
				right = (prev.x > p.x || next.x > p.x);
				
				if (top && bottom) {
					drawVerticalGcode(m, ts_mm, marg_mm, thick_mm, false);
				} else if (left && right) {
					m.rotate(HALF_PI);
					drawVerticalGcode(m, ts_mm, marg_mm, thick_mm, false);
				} else if (bottom && right) {
					drawCornerTLGcode(m, ts_mm, marg_mm, thick_mm, false);
				} else if (bottom && left) {
					drawCornerTRGcode(m, ts_mm, marg_mm, thick_mm, false);
				} else if (top && left) {
					drawCornerBRGcode(m, ts_mm, marg_mm, thick_mm, false);
				} else if (top && right) {
					drawCornerBLGcode(m, ts_mm, marg_mm, thick_mm, false);
				}
			}
		}
	}
	
	// --- GCode Geometry Helpers ---
	
	void drawVerticalGcode(PMatrix2D m, float t, float marg, float thick, boolean leftSide) {
		// Vertical: (0,0) is TL.
		// "Left" Wall (relative to flow Down): x=marg. y goes 0->t.
		// "Right" Wall (relative to flow Down): x=t-marg. y goes t->0 (reverse).
		
		if(leftSide) {
			addLine(m, marg, 0, marg, t);
		} else {
			addLine(m, t - marg, t, t - marg, 0); 
		}
	}
	
	void drawCornerTLGcode(PMatrix2D m, float t, float marg, float thick, boolean leftSide) {
		// Corner TL connects Bottom to Right.
		// Center (t, t).
		// Bottom Entrance: x=t-marg (Right wall), x=marg (Left wall).
		// Right Exit: y=t-marg (Bottom wall?), y=marg (Top wall?).
		
		// If walking Left Wall (Inner logic):
		// Radius = marg.
		// Start Angle: Loop from PI (Left) to PI+HALF_PI (Top)?
		// Geometry: Arc center (t, t).
		// Inner Arc (Left Wall): radius marg. 
		//    Starts at (t-marg, t)? No, `PI` is left -> (t-r, t) = (t-marg, t). Correct.
		//    Ends at (t, t-marg)? `PI+HALF` is up -> (t, t-r).
		//    Wait, Bottom Entrance means we come from y=t?
		//    Corner TL connects Bottom (y=t) to Right (x=t).
		//    So Inner Path: Starts (t-marg, t). Goes to (t, t-marg).
		//    Angle: PI -> PI+HALF_PI.
		
		// Outer Arc (Right Wall): radius thick+marg.
		//    Starts at (t-(t+m), t) = (-m, t)? No, margin arithmetic.
		//    Radius R = t - marg. (since width=t, gap=marg).
		//    Wait, thickness + margin + margin = tile?
		//    Actually `margin = (t - thick)/2`. So `thick + margin = t - margin`.
		//    So Outer Radius = t - margin.
		//    Starts at (t - R, t) = (marg, t).
		//    Ends at (t, t - R) = (t, marg).
		
		// Left/Right Side Logic:
		// "Left" wall depends on traversal direction.
		// If flow is Bottom -> Right:
		// Left Wall is Inner (radius marg).
		// Right Wall is Outer (radius t-marg).
		
		// flow check: `bottom && right`.
		// If prev is Bottom, we flow Bottom -> Right.
		// If next is Bottom, we flow Right -> Bottom.
		// We rely on standard drawing order?
		// `drawNoodle` has NO direction info in `cornerTL`. It just draws arcs.
		// BUT for 2-pass G-code, direction matters.
		
		// I must check direction relative to neighbors!
		// But in body loop, I don't know flow easily without checking index.
		// Actually I do: if(prev == bottom) -> Entering from bottom.
		
		// Wait, `cornerTL` assumes specific neighbor config (Bottom & Right).
		// So it is ALWAYS either B->R or R->B.
		// If Left Side Pass (Forward):
		//   If entering from Bottom: draw Inner Arc (Forward).
		//   If entering from Right: draw Outer Arc (Backward)? No.
		//   If entering from Right: Left Wall is the Outer Arc!
		
		// This is tricky.
		// Let's assume standard orientation based on `path[i-1]`.
		// Need `enteringFrom` logic.
		
		// Let's implement `enteringFrom` in the main loop and pass it.
		// But I cannot easily inject it now.
		// I'll calculate it in the helper if needed, or pass `top/bottom/left/right` flags AND `prev` point?
		
		// Alternative: `cornerTL` is symmetric.
		// Inner Arc ends: (t, t-m) and (t-m, t).
		// Outer Arc ends: (t, m) and (m, t).
		
		// If Left Wall Pass:
		//   We need to append a segment.
		//   Last point was ...
		//   If last point ~ (t-m, t), we are at Inner Start.
		//   If last point ~ (m, t), we are at Outer Start.
		//   We can detect proximity to deciding which way to draw!
		
		float cx = t, cy = t;
		float rInner = marg;
		float rOuter = t - marg; // (thick + marg)
		
		// Inner Arc endpoints: A(t-m, t), B(t, t-m).
		// Outer Arc endpoints: C(m, t), D(t, m).
		
		// Transform one probe point to see where we are?
		// `lastGcodeX/Y` is global.
		// Transform candidate starts to global. Check dist.
		
		if(leftSide) {
			// Try connecting to Inner A or Outer C?
			// Just use `connectArc` helper that checks distance?
			drawClosestArc(m, cx, cy, rInner, rOuter, PI, PI + HALF_PI); // PI to 1.5PI (270)
		} else {
			// Right Side Pass (Backward).
			drawClosestArc(m, cx, cy, rInner, rOuter, PI, PI + HALF_PI); // The helper handles proximity
		}
		
		
	}
	
	// Similar for other corners...
	void drawCornerTRGcode(PMatrix2D m, float t, float marg, float thick, boolean leftSide) {
		// Corner TR: Bottom to Left.
		// Center (0, t).
		// Quadrant: -HALF_PI (Top/Up? No) -> 0 (Right).
		// Processing 0 is Right (3 o'clock). -HALF_PI is Up (12 o'clock).
		// TR connects Left (x=0) to Bottom (y=t).
		// Arcs in Bottom-Right quadrant of the circle at (0,t)?
		// No, `cornerTR` draws `arc(0, t, ..., -HALF_PI, 0)`.
		// -90 to 0 degrees.
		// Center (0, t). 
		// Angle -90 (Up) -> (0, t-r). (x=0, y reduced). Connects to Left side? 
		//    Wait, (0, t) is Bottom-Left of the tile physically?
		//    Processing: (0,0) Top-Left. (0, t) Bottom-Left.
		//    Arc at (0, t). -90 is Up. 0 is Right.
		//    This matches "Bottom-Left" visually, but connects Left Wall to Bottom Wall?
		//    Function name `cornerTR` (Top Right).
		//    Logic: `bottom && left`. Connection Bottom <-> Left.
		//    Wait `cornerTR` usually means the noodle TURNS towards TR?
		//    Or is at TR?
		//    If I am at TR, I connect Left and Bottom? No.
		//    If I Connect Bottom and Left, I am likely a TR corner piece (visually lines are at TR).
		
		// Anyway, I stick to the ANGLES used in `Noodle.pde`.
		// TR: -HALF_PI to 0. (270 to 360). Center (0,t).
		drawClosestArc(m, 0, t, marg, t-marg, -HALF_PI, 0);
	}
	
	void drawCornerBRGcode(PMatrix2D m, float t, float marg, float thick, boolean leftSide) {
		// BR: Top <-> Left.
		// Center (0,0).
		// Angles: 0 to HALF_PI. (0 to 90).
		drawClosestArc(m, 0, 0, marg, t-marg, 0, HALF_PI);
	}
	
	void drawCornerBLGcode(PMatrix2D m, float t, float marg, float thick, boolean leftSide) {
		// BL: Top <-> Right.
		// Center (t, 0).
		// Angles: HALF_PI to PI. (90 to 180).
		drawClosestArc(m, t, 0, marg, t-marg, HALF_PI, PI);
	}
	
	// --- CAPS ---
	void drawHeadCapGcode(PMatrix2D m, float t, float marg, float thick, boolean leftSide) {
		// Head Cap uses `drawEnd`.
		// It just uses `arc` and `line`.
		// Procedural drawEnd:
		/*
			fill(fillColor);
			noStroke();
			rect(margin, tileSize/2, tileSize-margin*2, tileSize/2);
			arc(tileSize/2, tileSize/2, tileSize-margin*2, tileSize-margin*2, PI, TWO_PI);
		*/
		// That matches the visual.
		// Rect from Center-Y to Bottom. Arc on Top.
		// For Contour (Gcode):
		// Left Side: Line Up -> Arc Left-to-Right -> Line Down?
		// Actually Left implies "Left Wall".
		// Since we rotate so neighbor is "Down" (or handled by rotate),
		// The Cap is "Up".
		// `drawEnd` draws arc at `tileSize/2, tileSize/2`. Radius `(t-2m)/2`?
		// Diameter `t-2m`. So Radius `t/2 - m`.
		// Start PI, End TWO_PI. (Top Semicircle).
		
		// If Left Side (Forward):
		// We are ascending the Left Wall.
		// We encounter the Cap.
		// We trace the Arc.
		// And descend the Right Wall?
		// No, Left Side Pass handles Left Wall.
		// Right Side Pass handles Right Wall.
		// The CAP connects them.
		
		// If `leftSide` is true, we consider ourselves "Arriving" at the Cap.
		// BUT `drawEnd` connects `path[i]` and `neighbor`.
		// If i==0 (Head), neighbor is i+1.
		// Body is "Down" (visually). Cap is "Up".
		
		// Left Wall comes up x=marg.
		// Arc starts at x=marg?
		// Center x=t/2. Radius = t/2 - m.
		// x_start = t/2 - (t/2 - m) = m. CORRECT.
		// x_end = t/2 + (t/2 - m) = t - m. CORRECT.
		
		// So the ARC connects Left Wall Top to Right Wall Top.
		// In "Left Side Pass", do we draw the whole arc?
		// Or half?
		// Usually we draw the *entire* continuous loop.
		// My logic is:
		// Pass 1: Draw Left Wall (Segments).
		// THEN Draw Tail Cap (Connecting Left to Right).
		// Pass 2: Draw Right Wall (Segments).
		// THEN Draw Head Cap (Connecting Right to Left).
		
		// So `drawHeadCapGcode` is ONLY called at the END of Pass 2?
		// Function `writeGcode`:
		//   Loop Pass 2...
		//   drawHeadCapGcode(..., false).
		// Wait, I call it inside the loop at `i==0`.
		// But in Pass 2, `i` goes `len-1` down to `0`.
		// So `i==0` is the LAST step of Pass 2.
		// So yes, it connects the loop.
		
		// In Pass 1, `i==0` is the FIRST step.
		// But we don't draw cap at start of Pass 1?
		// Actually, we start at "Head Left Start".
		// Which is `(marg, y_start_of_body)`.
		// The Cap is "Before" this.
		// So in Pass 1 (Head), we assume we start *after* the cap?
		// Or does the Cap include the `rect` part?
		// `drawEnd` has `rect(margin, tileSize/2, ..., tileSize/2)`.
		// This rect extends from center to bottom.
		// So Head cell is HALF body, HALF cap.
		
		// Complex.
		// Let's rely on standard shapes.
		// `drawVertical` covers `0 to t`.
		// `drawEnd` covers `0 to t`?
		// The rect goes `t/2` to `t`.
		// The arc is at `t/2` (radius `r`). Top of arc is `t/2 - r`.
		// If `r = t/2 - m`. Top is `t/2 - (t/2 - m) = m`.
		// So Cap extends from `y=m` to `y=t`.
		// And `y=0` to `y=m` is empty margin?
		// Yes, `drawEnd` leaves space above?
		
		// If so, `drawVertical` which does `0 to t` would overlap?
		// Neighboring cells match up.
		
		// Logic:
		// Head:
		// Pass 1 (i=0): We just draw the "Left body" part of the cap cell?
		//   Rect Left: `(m, t/2)` to `(m, t)`.
		// Pass 2 (i=0): We draw "Right body" part?
		//   Rect Right: `(t-m, t)` to `(t-m, t/2)`.
		//   AND we draw the Arc connecting them?
		
		// I will just use `drawClosestArc` or `gcodeCurveLine` to draw the Head Arc.
		// If I call `drawHeadCapGcode` only at END of Pass 2, it draws the Arc.
		// If I call it at START of Pass 1, it implies nothing (just move to start).
		
		// So:
		// `drawHeadCapGcode`:
		//   If `leftSide` (Start of Pass 1):
		//     Move to (marg, t). (Bottom of cell, interface to body).
		//     Or Move to (marg, t/2)?
		//     If I want to trace the *whole* shape including the cap:
		//     Start at (marg, t). Line to (marg, t/2). Arc to (t-marg, t/2). Line to (t-marg, t).
		//     But this covers Left AND Right sides of the head cell.
		//     This breaks the "Left Pass / Right Pass" structure.
		//     Because Head is a turnaround.
		
		// Better:
		// Head Cell logic:
		//   Left Wall: Line (marg, t) -> (marg, t/2).
		//   Cap: Arc (marg, t/2) -> (t-marg, t/2).
		//   Right Wall: Line (t-marg, t/2) -> (t-marg, t).
		
		// My loops iterate ALL cells.
		// i=0 is Head.
		// Pass 1 (Left): Draw Left Wall of Head.
		//   Line (marg, t) -> (marg, t/2).
		//   End of Pass 1 (at tail): Draw Tail Arc.
		// Pass 2 (Right): Draw Right Wall of Head.
		//   Line (t-marg, t/2) -> (t-marg, t). (Reverse: t->t/2).
		//   End of Pass 2 (at head): Draw Head Arc.
		//   Arc (marg, t/2) -> (t-marg, t/2). (Reverse: t-marg -> marg).
		
		// This works perfectly!
		
		// Implementation:
		// `drawHeadCapGcode`:
		float cy = t/2.0;
		float r = (t/2.0) - marg;
		if(leftSide) {
			// Left Wall Segment: Bottom (t) to Center (cy).
			// Note: We are "Starting" at Head in Pass 1?
			// i=0. Direction is Down (0->1).
			// So "Start" of Noodle is Head.
			// Pass 1 traces Left Wall.
			// Start of Left Wall is at adhesion to Cap?
			// NO. Start of Noodle is the TIP of the Cap.
			// BUT we split loop into Left/Right.
			// Start of "Left Path" -> where does it start?
			// At the tip? Or at the tail?
			// I decided:
			// Pass 1: Head -> Body -> Tail. (Left Wall).
			// Pass 2: Tail -> Body -> Head. (Right Wall).
			// So Left Wall of Head Cell: (marg, cy) -> (marg, t)?
			// Or (marg, t) -> (marg, cy)?
			// If Body is "Down" (y increased).
			// Flow is Down.
			// So Left Wall goes (marg, cy) -> (marg, t).
			// Right Wall goes (t-marg, t) -> (t-marg, cy).
			// Head Arc connects Right Wall End (t-marg, cy) to Left Wall Start (marg, cy).
			// YES.
			
			// So `drawHeadCapGcode` (Left Side - Pass 1 Start):
			// Draw Line (marg, cy) -> (marg, t).
			addLine(m, marg, cy, marg, t);
		} else {
			// Right Side - Pass 2 End.
			// We are coming Up the Right Wall.
			// Value passed `leftSide` is false.
			// Draw Right Wall Segment: (t-marg, t) -> (t-marg, cy).
			addLine(m, t-marg, t, t-marg, cy);
			
			// AND Draw the Turnaround Arc!
			// Arc from (t-marg, cy) to (marg, cy).
			// Semicircle Top.
			// Center (t/2, cy). Radius r.
			// Start Angle 0 (Right). End Angle PI (Left).
			// Clockwise? No, 0->PI is clockwise? No, 0->PI is CounterClockwise on screen (0=Right, PI=Left, via Bottom?)
			// Processing Arc: 0 is Right. PI is Left. Positive angle = Clockwise? 
			// Processing +Y is Down.
			// 0=(1,0). PI/2=(0,1) (Down). PI=(-1,0).
			// So 0 -> PI goes via Down (Bottom).
			// We want Top Semicircle.
			// So PI -> TWO_PI (Left -> Top -> Right).
			// Or -PI -> 0.
			// Start Point: (t-marg, cy) aka Right side (Angle 0).
			// End Point: (marg, cy) aka Left side (Angle PI).
			// We want UP path.
			// 0 -> -PI (via Top).
			drawClosestArc(m, t/2.0, cy, r, r, 0, -PI);
		}
	}
	
	void drawTailCapGcode(PMatrix2D m, float t, float marg, float thick, boolean leftSide) {
		// Tail is inverted Head. Connects to `neighbor` (up).
		// Body comes from Up. Tail is Down.
		// Cap is at Bottom.
		// Rect from 0 to t/2?
		float cy = t/2.0;
		float r = (t/2.0) - marg;
		
		if(leftSide) {
			// Pass 1 End.
			// Coming down Left Wall.
			// Segment: (marg, 0) -> (marg, cy).
			addLine(m, marg, 0, marg, cy);
			
			// Turnaround Arc (Bottom).
			// Connect Left (marg, cy) to Right (t-marg, cy).
			// Angle PI (Left) -> 0 (Right) via Bottom.
			// Bottom is +Y. Angle PI -> 2PI? No PI->0 via positive?
			// PI (Left) -> 1.5PI (Top) -> 2PI (Right)? No that's Top.
			// We want Bottom.
			// PI (Left) -> HALF_PI (Down)? No HALF_PI is 90.
			// PI -> HALF_PI is -90 deg.
			// We want PI -> 0.
			// Processing angles increase Clockwise.
			// PI -> 1.5PI (Up) -> 2PI (Right).
			// PI -> 0.5PI (Down)? No 180 -> 90.
			// Let's visualize: 0=Right. 90=Down. 180=Left. 270=Up.
			// We start Left (180). We want to go Right (0). Via Bottom (90? No, 90 is between 0 and 180).
			// So 180 -> 90 -> 0.
			// Just linear range PI -> 0?
			// drawClosestArc checks distance, handles range.
			drawClosestArc(m, t/2.0, cy, r, r, PI, 0); 
		} else {
			// Pass 2 Start.
			// Starting ascent of Right Wall.
			// Segment: (t-marg, cy) -> (t-marg, 0).
			addLine(m, t-marg, cy, t-marg, 0);
		}
	}
	
	// --- ARC HELPER ---
	void drawClosestArc(PMatrix2D m, float cx, float cy, float r1, float r2, float startAng, float stopAng) {
		// Identify which radius is closest to current pen position.
		// Generate points for both starts.
		
		// Candidate 1: Radius r1. Start Angle.
		float sx1 = cx + cos(startAng) * r1;
		float sy1 = cy + sin(startAng) * r1;
		PVector ps1 = transform(m, sx1, sy1);
		
		// Candidate 2: Radius r2. Start Angle.
		float sx2 = cx + cos(startAng) * r2;
		float sy2 = cy + sin(startAng) * r2;
		PVector ps2 = transform(m, sx2, sy2);
		
		// Also check Stop angles? Because we might be traversing Reverse.
		float ex1 = cx + cos(stopAng) * r1;
		float ey1 = cy + sin(stopAng) * r1;
		PVector pe1 = transform(m, ex1, ey1);
		
		float ex2 = cx + cos(stopAng) * r2;
		float ey2 = cy + sin(stopAng) * r2;
		PVector pe2 = transform(m, ex2, ey2);
		
		// We have 4 endpoints. 2 arcs.
		// Current pos: lastGcodeX, lastGcodeY.
		
		float dS1 = dist(lastGcodeX, lastGcodeY, ps1.x, ps1.y);
		float dE1 = dist(lastGcodeX, lastGcodeY, pe1.x, pe1.y);
		float dS2 = dist(lastGcodeX, lastGcodeY, ps2.x, ps2.y);
		float dE2 = dist(lastGcodeX, lastGcodeY, pe2.x, pe2.y);
		
		float minD = min(dS1, min(dE1, min(dS2, dE2)));
		
		float curR = (minD == dS1 || minD == dE1) ? r1 : r2;
		boolean forward = (minD == dS1 || minD == dS2);
		
		drawArc(m, cx, cy, curR, startAng, stopAng, forward);
	}
	
	void drawArc(PMatrix2D m, float cx, float cy, float r, float start, float stop, boolean forward) {
		float delta = (stop - start); // full span
		
		// Dynamic resolution: Lower point count for smoother execution.
		// Reference G-code suggests segments of ~5-10mm.
		float arcLen = r * abs(delta);
		// Resolution: ~0.2 segments per mm (1 segment every 5mm). min 6 steps.
		int steps = max(6, int(arcLen * 0.2));

		// If traversing reverse, we go stop -> start
		// But loop calculates pos based on k.
		// If forward: k=0 -> start. k=1 -> stop.
		// If !forward: k=0 -> stop. k=1 -> start.
		
		for(int i=1; i<=steps; i++) {
			float k = float(i) / float(steps);
			float ang;
			if (forward) {
				ang = start + delta * k;
			} else {
				ang = stop - delta * k;
			}
			
			float px = cx + cos(ang) * r;
			float py = cy + sin(ang) * r;
			PVector ipv = transform(m, px, py);
			
			gcodeCurveLine(lastGcodeX, lastGcodeY, ipv.x, ipv.y); // using lastGcode as start implicitly
		}
	}
	
	void addLine(PMatrix2D m, float x1, float y1, float x2, float y2) {
		PVector p1 = transform(m, x1, y1);
		PVector p2 = transform(m, x2, y2);
		gcodeLine(p1.x, p1.y, p2.x, p2.y);
	}
	
	PVector transform(PMatrix2D m, float x, float y) {
		float gx = m.m00*x + m.m01*y + m.m02;
		float gy = m.m10*x + m.m11*y + m.m12;
		return new PVector(gx, gy);
	}
	
	void horizontalJoin(int type) {
		horizontalShape(joiners[type-1]);
	}
	
	void drawNoodle(boolean useTwists) {
		randomSeed(seed);
		
		boolean fills = useFills;
		int start = 1;
		if (useFills) start = 0;
		for(int j = start ; j < 2; j++){
			
			for(int i = 0; i < path.length; i++){
				
				if(j == 0){
					noStroke();
					fill(fillColor);
					
				} else {
					fills = false;
					stroke(0);
					noFill();
					strokeWeight(strokeSize);
				}
				Point p = path[i];
				
				pushMatrix();
				translate(p.x * tileSize, p.y * tileSize);
				if(i == 0){
					drawEnd(fills, path[i], path[i + 1]);
				}else if( i == path.length -1){
					drawEnd(fills, path[i], path[i - 1]);
				} else {
					
					Point prev = path[i-1];
					Point next = path[i+1];
					
					boolean top = prev.y < p.y || next.y < p.y;
					boolean right = prev.x > p.x || next.x > p.x;
					boolean left = prev.x < p.x || next.x < p.x;
					boolean bottom = prev.y > p.y || next.y > p.y;
					
					if(top && bottom ){
						if(p.type == CellType.V_CROSSED){
							verticalCrossed(fills);
						} else if (useTwists && p.joinType == 0){
							verticalTwist(fills);
						}  else if(useJoiners && joiners != null && p.joinType > 0 && p.joinType <= joiners.length) {
							verticalJoin(p.joinType);
						} else {
							vertical(fills);
						}
					} else if(left && right){
						if(p.type == CellType.H_CROSSED){
							horizontalCrossed(fills);
						} else if (useTwists && p.joinType == 0){
							horizontalTwist(fills);
						} else if(useJoiners && joiners != null && p.joinType > 0 && p.joinType <= joiners.length){
							horizontalJoin(p.joinType);
						} else {
							horizontal(fills);
						}
					} else if(left && bottom){
						cornerTR(fills);
					} else if(top && left){
						cornerBR(fills);
					} else if(top && right) {
						cornerBL(fills);
					} else if(bottom && right){
						cornerTL(fills);
					}
				}
				popMatrix();
				
				
			}
		}
	}
	
	void draw(int size, float pct, boolean useTwists) {
		if(tileSize != size || thicknessPct != pct){
			calculateSizes(size, pct);
		}
		
		drawNoodle(useTwists);
	}

	void verticalCrossed(boolean isFill) {
		if(isFill){
			// rect(margin, 0, tileSize - margin * 2, margin);
			// rect(margin , tileSize - margin, tileSize - margin * 2, margin);
			vertical(isFill);
		} else {
			line(margin, 0, margin, margin);
			line(margin, tileSize - margin, margin, tileSize );
			
			line(tileSize - margin, 0, tileSize - margin, margin);
			line(tileSize - margin, tileSize - margin, tileSize - margin, tileSize);
		}
	}

	void horizontalCrossed(boolean isFill) {
		if(isFill){
			// rect(0, margin, margin, tileSize - margin *2);
			// rect(tileSize - margin, margin, margin, tileSize - margin *2);
			horizontal(isFill);
		} else {
			line(0, margin, margin, margin);
			line(tileSize - margin, margin, tileSize, margin);

			line(0, tileSize - margin, margin, tileSize - margin);
			line(tileSize - margin, tileSize - margin, tileSize, tileSize - margin);
		}
	}
	
	void cornerTL(boolean isFill) {
		arc(tileSize, tileSize, (thickness + margin)*2, (thickness + margin)*2, PI, PI + HALF_PI);
		if(isFill) fill(paperColor);
		arc(tileSize, tileSize, margin * 2, margin * 2, PI, PI + HALF_PI);
	}
	
	void cornerTR(boolean isFill) {
		arc(0, tileSize, (thickness + margin)*2 , (thickness + margin)*2,-HALF_PI, 0);
		if(isFill) fill(paperColor);
		arc(0, tileSize, margin * 2, margin *2, -HALF_PI, 0);
	}
	
	void cornerBR(boolean isFill) {
		arc(0, 0, (thickness + margin)*2, (thickness + margin)*2, 0, HALF_PI);
		if(isFill) fill(paperColor);
		arc(0, 0, margin * 2, margin * 2, 0, HALF_PI);
	}
	
	void cornerBL(boolean isFill) {
		arc(tileSize, 0, (thickness + margin)*2, (thickness + margin)*2, HALF_PI, PI);
		if(isFill) fill(paperColor);
		arc(tileSize, 0, margin * 2, margin * 2, HALF_PI, PI);
		
	}
	
	void vertical(boolean isFill) {
		if(useRoughLines){
			roughLineV(margin, 0, tileSize);
			roughLineV(tileSize - margin, 0, tileSize);
		} else {
			
			if(isFill){
				rect(margin, 0, tileSize - margin*2, tileSize);
			} else {
				line(margin, 0, margin, tileSize);
				line( tileSize - margin, tileSize, tileSize - margin, 0);
			}
		}		
	}
	
	// void verticalTwist() {
	// 	float twistDepth = tileSize / 2;
	// 	bezier(margin, 0, margin,   twistDepth, tileSize - margin,   tileSize - twistDepth, tileSize-margin, tileSize);
	// 	bezier( tileSize - margin, 0,    tileSize - margin, twistDepth,     margin, tileSize - twistDepth,    margin, tileSize);
	// }
	
	
	
	void horizontal(boolean isFill) {
		if(useRoughLines){
			roughLineH(0, margin, tileSize);
			roughLineH(0, tileSize - margin, tileSize);
		} else {
			if(isFill){
				rect(0, margin, tileSize, tileSize - margin * 2);
			} else {
				line(0, margin, tileSize, margin);
				line(0, tileSize - margin, tileSize, tileSize - margin);
			}
		}
	}
	
// 	void horizontalTwist() {
// 		float twistDepth = tileSize / 2;
// 		bezier( 0, margin, twistDepth,margin, tileSize - (twistDepth),   tileSize-margin,   tileSize , tileSize - margin);
// 		bezier( 0, tileSize - margin, twistDepth, tileSize-margin, tileSize -twistDepth, margin,      tileSize, margin);
// 	}
}