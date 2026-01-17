// filepath: /Users/samuele/Progetti/QUADRI/GENERATIVE/generative-noodles-main/sketch/noodlePath.pde
// Appendo le nuove funzioni alla fine del file

int countFreeNeighbors(Point p, int[][] cells) {
	int count = 0;
	int w = cells.length;
	int h = cells[0].length;
	// Check 4 directions
	if (p.x > 0 && cells[p.x - 1][p.y] == CellType.EMPTY) count++;
	if (p.x < w - 1 && cells[p.x + 1][p.y] == CellType.EMPTY) count++;
	if (p.y > 0 && cells[p.x][p.y - 1] == CellType.EMPTY) count++;
	if (p.y < h - 1 && cells[p.x][p.y + 1] == CellType.EMPTY) count++;
	return count;
}

Point[] createSmartPath(int[][] cells) {
	// Determina la lunghezza massima possibile (tutte le celle libere)
	int maxPossibleLen = 0;
	for(int x=0; x<cells.length; x++){
		for(int y=0; y<cells[0].length; y++){
			if(cells[x][y] == CellType.EMPTY) maxPossibleLen++;
		}
	}
	// Aggiungi buffer e un minimo
	maxPossibleLen = max(maxPossibleLen + 100, minLength); 
	
	Point[] path = new Point[maxPossibleLen];
	
	Point start = findStartPoint(cells);
	if (start == null) return null; // Nessun punto di partenza disponibile

	path[0] = start;
	cells[start.x][start.y] = CellType.OCCUPIED;
	
	int count = 1;
	
	// Warnsdorff's Rule: move to neighbor with fewest available moves
	// Loop finché non ci blocchiamo
	for (int i = 1; i < maxPossibleLen; i++) {
		Point prev = path[count - 1];
		
		// False per 'isLastCell' perché vogliamo continuare il più possibile
		ArrayList<String> availableDirs = findAvailableDirections(prev, false); // canCross?
		
		if (availableDirs.size() == 0) {
			// Stuck
			break;
		}
		
		String bestDir = "";
		int minDegree = 9999;
		ArrayList<String> bestCandidates = new ArrayList<String>();
		
		for (String dir : availableDirs) {
			Point nextP = getNextPointForDirection(prev, dir);
			// Calcola euristica su nextP (quanti vicini liberi ha?)
			// Nota: countFreeNeighbors controlla solo EMPTY. 
			// Se 'canCrossCell' è attivo, might be misleading, ma è una buona euristica base.
			int degree = countFreeNeighbors(nextP, cells);
			
			if (degree < minDegree) {
				minDegree = degree;
				bestCandidates.clear();
				bestCandidates.add(dir);
			} else if (degree == minDegree) {
				bestCandidates.add(dir);
			}
		}
		
		// Scegli a caso tra i migliori candidati (ties)
		if (bestCandidates.size() > 0) {
			bestDir = bestCandidates.get(floor(random(bestCandidates.size())));
		} else {
			// Fallback (non dovrebbe succedere se availableDirs > 0)
			bestDir = availableDirs.get(floor(random(availableDirs.size())));
		}
		
		Point p = getNextPointForDirection(prev, bestDir);
		if (p != null) {
			if (!cellIsEmpty(p.x, p.y)) {
				boolean didAdd = addCrossAtCell(p, bestDir);
				if (!didAdd) {
					addCrossToPathAtCell(p, path, bestDir);
				}
			}

			p.joinType = floor(random(0, NUM_JOIN_TYPES));
			p.type = CellType.OCCUPIED;
			path[count] = p;
			markCellTypeWithPathAndIndex(path, count);
			count++;
		}
	}
	
	if (count > 2) {
		Point[] finalPath = (Point[]) subset(path, 0, count);
		return finalPath;
	} else {
		clearCells(cells, (Point[]) subset(path, 0, count));
		return null;
	}
}
