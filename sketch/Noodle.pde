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
		// If thickness is ~0 (collapsed)
		boolean isCollapsed = (thick_mm < 0.1); 
		
		PMatrix2D m = new PMatrix2D();
		
		// --- PASS 1: LEFT WALL (Forward) ---
		// Traverses Head -> Tail. Draws the "Left Wall" relative to forward motion.
		for(int i = 0; i < path.length; i++) {
			Point p = path[i];
			m.reset();
			m.translate(startX + p.x * ts_mm, startY + p.y * ts_mm);
			
			Point prev = (i > 0) ? path[i-1] : null;
			Point next = (i < path.length - 1) ? path[i+1] : null;

			// Determine entering/exiting relative to P
			// For Pass 1 (Forward): Enter from Prev, Exit to Next.
			
			if (i == 0) {
				// HEAD (Start of Pass 1)
				// Virtual entry from "Center of Head"? No, just handled as start.
				// We draw the Left Rect side.
				drawHeadBodyGcode(m, ts_mm, marg_mm, true, p, next);
			} else if (i == path.length - 1) {
				// TAIL (End of Pass 1)
				// We draw Left Rect side.
				drawTailBodyGcode(m, ts_mm, marg_mm, true, p, prev);
				// Then Draw Cap Arc (Left -> Right)
				if(!isCollapsed) drawTailCapArcGcode(m, ts_mm, marg_mm, p, prev);
			} else {
				// BODY
				// Draw Left Wall of motion Prev -> P -> Next
				drawBodyGcode(m, ts_mm, marg_mm, true, p, prev, next);
			}
		}
		
		if(isCollapsed) return; 
		
		// --- PASS 2: RIGHT WALL (Backward) ---
		// Traverses Tail -> Head. Draws the "Right Wall" relative to original Forward motion?
		// NO. We traverse physical path backward.
		// If we walk backwards, the "Original Right Wall" is on our LEFT.
		// So we draw the Left Wall relative to our Backward motion.
		// Motion is Next -> P -> Prev.
		
		for(int i = path.length - 1; i >= 0; i--){
			Point p = path[i];
			m.reset();
			m.translate(startX + p.x * ts_mm, startY + p.y * ts_mm);
			
			Point prev = (i > 0) ? path[i-1] : null;
			Point next = (i < path.length - 1) ? path[i+1] : null;

			if (i == path.length - 1) {
				// TAIL (Start of Pass 2)
				// Draw Right Side (which is Left of Backward motion)
				drawTailBodyGcode(m, ts_mm, marg_mm, false, p, prev);
			} else if (i == 0) {
				// HEAD (End of Pass 2)
				// Draw Right Side (Left of Backward motion)
				drawHeadBodyGcode(m, ts_mm, marg_mm, false, p, next);
				// Then Draw Head Cap Arc (Left of Bwd motion -> Right of Bwd motion aka Start of Fwd)
				drawHeadCapArcGcode(m, ts_mm, marg_mm, p, next);
			} else {
				// BODY
				// Motion: Next -> P -> Prev.
				// We pass 'next' as 'from', 'prev' as 'to'.
				drawBodyGcode(m, ts_mm, marg_mm, false, p, next, prev);
			}
		}
	}
	
	// --- GCode Helpers ---
	
	// Draw the Rect part of the Head (or Start cell).
	// isPass1: true if Forward Pass (Left Wall), false if Backward Pass (Right Wall).
	// Note: 'next' is the body neighbor.
	void drawHeadBodyGcode(PMatrix2D m, float t, float marg, boolean isPass1, Point p, Point next) {
		// Orientation: Head points AWAY from next.
		// Calculate rotation so Head is "Up".
		float rot = 0;
		if(next.x < p.x) { rot = HALF_PI; }      // Next is Left. Head points Right. (Wait. neighbor < p -> neighbor Left. Head points away -> Right? No. drawNoodle rotates so neighbor is Down aka PI/2? No.)
		// logic from drawNoodle:
		// neighbor < p (Left): rotate(HALF_PI). (0,1)->(-1,0). Y(Down) becomes X(Left).
		// So Body is Left. Head is Right?
		// No. drawEnd draws rect relative to (0,0) (TopLeft).
		// Wait. `drawEnd` logic:
		// if neighbor Left: rotate(HALF_PI).
		// rect(margin, t/2, ...).
		// t/2 is Center Y.
		// So it draws in Positive Y relative to rotation.
		// Rotated Y+ is X-. (Down -> Left).
		// So Rect is on Left. Body is Left.
		// So Head is Right.
		// Correct.
		// So relative to rotated frame: Body is Down (+Y). Head is Up (-Y)?
		// No, rect is (margin, t/2) to (w, t). Y goes t/2 -> t.
		// That is POSITIVE Y.
		// So Body is in Positive Y direction.
		// Head Tip is at Center Y (t/2).
		
		// In `drawHeadBodyGcode`, we want to draw the wall segments.
		// Frame: Body is DOWN (+Y). Head Tip is UP (Y < t/2? No, Y=t/2).
		// Left Wall (Pass 1): x=marg. y creates line.
		// Pass 1 (Head start): Start at Cap Interface (y=t/2)?
		// Pass 1 is Left Wall of path.
		// Path starts at Head.
		// Left Wall goes along x=marg, from t/2 to t (Body Interface).
		// Pass 2 (Head end): Arrive from Body.
		// Right Wall (Left of Bwd): x=t-marg. from t to t/2.
		
		if(next.x < p.x) { rot = HALF_PI; }
		else if(next.x > p.x) { rot = -HALF_PI; }
		else if(next.y < p.y) { rot = PI; }
		else { rot = 0; }
		m.rotate(rot); // Now Body is Down (+Y).
		
		float cy = t/2.0;
		if(isPass1) {
			// Forward Left: Start at Cap Line (cy), go to Body (t).
			addLine(m, marg, cy, marg, t);
		} else {
			// Backward Right (Left of Bwd): Start at Body (t), go to Cap Line (cy).
			addLine(m, t-marg, t, t-marg, cy);
		}
	}
	
	// Draw the Head Cap Arc (Connecting Right Wall End to Left Wall Start).
	// Calls at end of Pass 2.
	void drawHeadCapArcGcode(PMatrix2D m, float t, float marg, Point p, Point next) {
		float rot = 0;
		if(next.x < p.x) { rot = HALF_PI; }
		else if(next.x > p.x) { rot = -HALF_PI; }
		else if(next.y < p.y) { rot = PI; }
		else { rot = 0; }
		m.rotate(rot); 
		
		float cy = t/2.0;
		float r = (t/2.0) - marg;
		// Connect (t-marg, cy) to (marg, cy).
		// Via Top (-Y).
		// Start Angle: 0 (Right). Stop Angle: PI (Left).
		// Direction: 0 -> -PI (CCW via top). 
		// Or 0 -> PI? 0->PI is CW (via Bottom +Y). We want Top.
		// So 0 -> -PI.
		drawArcGcode(m, t/2.0, cy, r, 0, -PI);
	}
	
	// Logic for Tail is inverted.
	// Body is Up (-Y relative to tail? No).
	// Tail neighbor is `prev`.
	// Tail points AWAY from prev.
	// Same rotation logic: Rotate so prev is Down (+Y).
	// Tail Tip is Up (Y=t/2).
	
	void drawTailBodyGcode(PMatrix2D m, float t, float marg, boolean isPass1, Point p, Point prev) {
		float rot = 0;
		if(prev.x < p.x) { rot = HALF_PI; }
		else if(prev.x > p.x) { rot = -HALF_PI; }
		else if(prev.y < p.y) { rot = PI; }
		else { rot = 0; }
		m.rotate(rot);
		
		float cy = t/2.0;
		if(isPass1) {
			// Forward Left (Arriving at Tail): Body (t) -> Cap Line (cy).
			addLine(m, marg, t, marg, cy);
		} else {
			// Backward Right (Leaving Tail): Cap Line (cy) -> Body (t).
			addLine(m, t-marg, cy, t-marg, t);
		}
	}
	
	void drawTailCapArcGcode(PMatrix2D m, float t, float marg, Point p, Point prev) {
		float rot = 0;
		if(prev.x < p.x) { rot = HALF_PI; }
		else if(prev.x > p.x) { rot = -HALF_PI; }
		else if(prev.y < p.y) { rot = PI; }
		else { rot = 0; }
		m.rotate(rot);
		
		float cy = t/2.0;
		float r = (t/2.0) - marg;
		// Connect Left (marg, cy) to Right (t-marg, cy).
		// Via Top (-Y). (Tip of tail).
		// Start Angle: PI (Left). Stop Angle: 0 (Right).
		// Direction: PI -> 0?
		// PI -> 0 is linear decrement? Or via Top?
		// PI (180) -> 0. Via 90? No, 90 is Down.
		// Via 270 (-90)? Yes.
		// PI -> 0 (CCW). NO. CW is increasing.
		// PI -> 2PI (via 3PI/2 270).
		// Or PI -> -PI?
		// Let's use negative check.
		// PI -> 0 via negative logic? 
		// Start PI. Stop 0. Delta -PI.
		// PI -> 0. Midpoint PI/2 (90, Down).
		// We want Top (-90).
		// So we want PI -> 2PI.
		// drawArcGcode handles simple lerp.
		drawArcGcode(m, t/2.0, cy, r, PI, TWO_PI); 
	}
	
	// Universal Body Drawer: Draws the Wall on the LEFT of the motion from->to.
	void drawBodyGcode(PMatrix2D m, float t, float marg, boolean isPass1, Point p, Point pFrom, Point pTo) {
		// Determine visual case (Vertical, Corner, etc).
		boolean top = (pFrom.y < p.y || pTo.y < p.y);
		boolean bottom = (pFrom.y > p.y || pTo.y > p.y);
		boolean left = (pFrom.x < p.x || pTo.x < p.x);
		boolean right = (pFrom.x > p.x || pTo.x > p.x);
		
		if (top && bottom) {
			// VERTICAL
			// Entering from?
			if (pFrom.y < p.y) {
				// From Top (Moving Down).
				// Left Wall is x=marg.
				addLine(m, marg, 0, marg, t);
			} else {
				// From Bottom (Moving Up).
				// Left Wall is x=t-marg (Right side of tile).
				addLine(m, t-marg, t, t-marg, 0);
			}
		} else if (left && right) {
			// HORIZONTAL
			if (pFrom.x < p.x) {
				// From Left (Moving Right).
				// Left Wall is Top (y=marg).
				addLine(m, 0, marg, t, marg);
			} else {
				// From Right (Moving Left).
				// Left Wall is Bottom (y=t-marg).
				addLine(m, t, t-marg, 0, t-marg);
			}
		} else if (bottom && right) {
			// CORNER TL (Bottom <-> Right)
			// Center (t, t). 
			if (pFrom.y > p.y) {
				// From Bottom (Moving Up/Right).
				// Entrance: Bottom x=marg. (Left relative to Up).
				// Exit: Right y=marg. (Left relative to Right).
				// Turn is Right. Wall is Outer. Radius t-marg.
				// Arc: Start (marg, t). End (t, marg).
				// Center (t,t). 
				// Start Angle: (marg, t) -> (t-R, t) -> PI.
				// End Angle: (t, marg) -> (t, t-R) -> -HALF_PI (270).
				// Dir: PI -> 270. CW. (Decreasing angle in Processing?) No, P5 +Angle is CW.
				// 0=Right. 90=Down. 180=Left. 270=Up.
				// 180 -> 270 is +90 deg. This is B -> L.
				// We want B -> R?
				// Wait. Bottom is 90? No, Bottom of tile is y=t.
				// Relative to Center (t,t).
				// (marg, t) is (-x, 0). Angle PI.
				// (t, marg) is (0, -y). Angle 270.
				// PI(180) -> 270. This describes Bottom-Left to Top-Right arc relative to center.
				// Yes.
				drawArcGcode(m, t, t, t-marg, PI, PI+HALF_PI);
			} else {
				// From Right (Moving Left/Down).
				// Turn Left. Wall is Inner. Radius marg.
				// Start (t, t-marg). Angle 270.
				// End (t-marg, t). Angle PI.
				// 270 -> 180.
				drawArcGcode(m, t, t, marg, PI+HALF_PI, PI);
			}
		} else if (bottom && left) {
			// CORNER TR (Bottom <-> Left)
			// Center (0, t).
			if (pFrom.y > p.y) {
				// From Bottom.
				// Moving Up/Left. Turn Left. Inner Wall. Radius marg.
				// Entrance: Bottom x=t-marg (Right relative to tile, Left relative to Up-Left motion? No).
				// Up motion vector (0,-1). Left is (-1,0) aka Left side.
				// Entrance x=0+marg? No.
				// Center (0,t). Inner R=marg.
				// Arc is in TR quadrant of center?
				// Relative to (0,t): x>0, y<0.
				// Connects x=marg side?
				// TR connects Bottom (y=t) and Left (x=0).
				// Inner wall: Start (t-m, t)? No, dist to (0,t) is t-m? No.
				// Inner R=marg.
				// Points: (m, t) and (0, t-m).
				// (m, t) relative to (0,t) is (m, 0). Angle 0.
				// (0, t-m) relative to (0,t) is (0, -m). Angle 270 (-90).
				// Motion B -> L.
				// Start (m,t) -> End (0, t-m).
				// Angle 0 -> 270. 
				drawArcGcode(m, 0, t, marg, 0, -HALF_PI);
			} else {
				// From Left.
				// Moving Right/Down. Turn Right. Outer Wall. Radius t-marg.
				// Start (0, m). End (t-m, t).
				// (0, m) relative to (0,t) is (0, m-t) = (0, -(t-m)). Angle 270 (-90).
				// (t-m, t) relative is (t-m, 0). Angle 0.
				// 270 -> 0.
				drawArcGcode(m, 0, t, t-marg, -HALF_PI, 0); 
			}
		} else if (top && left) {
			// CORNER BR (Top <-> Left)
			// Center (0,0).
			if (pFrom.y < p.y) {
				// From Top.
				// Moving Down/Left. Turn Right. Outer Wall. R=t-m.
				// Entrance: Top (x=t-m, y=0)?
				// Center (0,0). R=t-m.
				// Start (t-m, 0). Angle 0.
				// Exit Left (x=0, y=t-m). Angle 90 (HALF_PI).
				// 0 -> 90.
				drawArcGcode(m, 0, 0, t-marg, 0, HALF_PI);
			} else {
				// From Left.
				// Moving Right/Up. Turn Left. Inner Wall. R=m.
				// Start (0, m). Angle 90.
				// End (m, 0). Angle 0.
				// 90 -> 0.
				drawArcGcode(m, 0, 0, marg, HALF_PI, 0);
			}
		} else if (top && right) {
			// CORNER BL (Top <-> Right)
			// Center (t, 0).
			if (pFrom.y < p.y) {
				// From Top.
				// Moving Down/Right. Turn Left. Inner Wall. R=m.
				// Start (t-m, 0). Relative (-m, 0). Angle PI.
				// End (t, m). Relative (0, m). Angle HALF_PI.
				// PI -> HALF_PI.
				drawArcGcode(m, t, 0, marg, PI, HALF_PI);
			} else {
				// From Right.
				// Moving Left/Up. Turn Right. Outer Wall. R=t-m.
				// Start (t, t-m). Relative (0, t-m). Angle HALF_PI.
				// End (m, 0). Relative (m-t, 0). Angle PI.
				// HALF_PI -> PI.
				drawArcGcode(m, t, 0, t-marg, HALF_PI, PI);
			}
		}
	}
	
	// MODIFIED: Uses nearest-neighbor traversal to minimize G0 jumps.
	void drawArcGcode(PMatrix2D m, float cx, float cy, float r, float start, float stop) {
		float delta = (stop - start); 
		float arcLen = r * abs(delta);
		// Increase resolution: 5 steps minimum, or 1 step per 2mm.
		int steps = max(6, int(arcLen * 0.5)); 
        
        // Transform Start Point
        float px_start = cx + cos(start) * r;
        float py_start = cy + sin(start) * r;
        PVector pStart = transform(m, px_start, py_start);

        // Transform End Point
        float px_end = cx + cos(stop) * r;
        float py_end = cy + sin(stop) * r;
        PVector pEnd = transform(m, px_end, py_end);
        
        // Distances from current pen position
        float dStart = dist(lastGcodeX, lastGcodeY, pStart.x, pStart.y);
        float dEnd = dist(lastGcodeX, lastGcodeY, pEnd.x, pEnd.y);
        
        if (dStart <= dEnd) {
             // Forward: Start -> Stop
             float prevX = pStart.x;
             float prevY = pStart.y;
             
             for(int i=1; i<=steps; i++) {
                float k = float(i) / float(steps);
                float ang = start + delta * k;
			    float px = cx + cos(ang) * r;
			    float py = cy + sin(ang) * r;
			    PVector ipv = transform(m, px, py);
			    
                gcodeLine(prevX, prevY, ipv.x, ipv.y); 
                prevX = ipv.x;
                prevY = ipv.y;
             }
        } else {
            // Backward: Stop -> Start
            float prevX = pEnd.x;
            float prevY = pEnd.y;
             
             for(int i=1; i<=steps; i++) {
                float k = float(i) / float(steps);
                // Inverse direction
                float ang = stop - delta * k;
			    float px = cx + cos(ang) * r;
			    float py = cy + sin(ang) * r;
			    PVector ipv = transform(m, px, py);
			    
                gcodeLine(prevX, prevY, ipv.x, ipv.y); 
                prevX = ipv.x;
                prevY = ipv.y;
             }
        }
	}
	
	void addLine(PMatrix2D m, float x1, float y1, float x2, float y2) {
		PVector p1 = transform(m, x1, y1);
		PVector p2 = transform(m, x2, y2);
		// Use nearest-neighbor logic
		drawBestSegment(p1.x, p1.y, p2.x, p2.y);
	}
	
	// NEW: Chooses direction A->B or B->A based on proximity to current pen pos
	void drawBestSegment(float x1, float y1, float x2, float y2) {
        float d1 = dist(lastGcodeX, lastGcodeY, x1, y1);
        float d2 = dist(lastGcodeX, lastGcodeY, x2, y2);
        
        if (d1 <= d2) {
            gcodeLine(x1, y1, x2, y2);
        } else {
            gcodeLine(x2, y2, x1, y1);
        }
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
