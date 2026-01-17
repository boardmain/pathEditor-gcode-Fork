import java.util.ArrayList;
import java.util.Collections;

// Direction constants: 0=Up, 1=Right, 2=Down, 3=Left
final int DIR_UP = 0;
final int DIR_RIGHT = 1;
final int DIR_DOWN = 2;
final int DIR_LEFT = 3;

class ContourPoint {
  int x, y;
  ContourPoint(int _x, int _y) { x = _x; y = _y; }
}

// Trova tutti i contorni (isole) nella griglia blackoutCells
// Ritorna una lista di array di Point, dove ogni array è un path chiuso
ArrayList<Point[]> findAllContours(int[][] grid) {
  int w = grid.length;
  int h = grid[0].length;
  boolean[][] visited = new boolean[w][h]; 
  ArrayList<Point[]> allContours = new ArrayList<Point[]>();
  
  // Scansione della griglia
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      // Se troviamo una cella "piena" (forma) che non è ancora visitata e è un bordo...
      // wait, per trovare tutti i contorni, basta trovare un pixel pieno non visitato che è sul bordo.
      // E' sul bordo se ha almeno un vicino vuoto o fuori bounds.
      if (isSolid(x, y, grid) && !visited[x][y] && isBoundary(x, y, grid)) {
        Point[] contour = traceSingleContour(x, y, grid, visited);
        if (contour != null && contour.length > 2) {
          allContours.add(contour);
          // Marca tutto il contorno come visitato?
          // Visited viene aggiornato dentro traceSingleContour
        }
      }
    }
  }
  return allContours;
}

boolean isSolid(int x, int y, int[][] grid) {
  if (x < 0 || y < 0 || x >= grid.length || y >= grid[0].length) return false;
  // Assumiamo che CellType.EMPTY (assegnato da ImageTools) sia "SOLIDO" per il Noodle, 
  // perché nel context di ImageTools abbiamo detto: Scuro (immagine) -> EMPTY.
  // E i noodle camminano su EMPTY. 
  // Quindi qui "Solid for shape" means "Empty for Noodle logic".
  return grid[x][y] == CellType.EMPTY || grid[x][y] == CellType.OCCUPIED || grid[x][y] > 0 && grid[x][y] != CellType.BLACKOUT; 
  // Attenzione: nel codice originale, EMPTY=0, BLACKOUT=12. 
  // ImageTools fa: pixel scuro -> EMPTY, pixel chiaro -> BLACKOUT.
  // Quindi la "forma" visibile sono le celle EMPTY.
  
  // Correggo per sicurezza: consideriamo "solido" tutto ciò che non è BLACKOUT.
  // Però in ImageTools: blackoutCells[x][y] = CellType.BLACKOUT (sfondo).
  // Quindi tutto ciò che NON è BLACKOUT è forma.
  // Nella logica originale, 0 è EMPTY.
}

boolean isBoundary(int x, int y, int[][] grid) {
  // Controlla 4 vicini. Se uno è !Solid (quindi BLACKOUT o fuori bounds), è boundary.
  if (!isSolid(x, y - 1, grid)) return true; // Up
  if (!isSolid(x + 1, y, grid)) return true; // Right
  if (!isSolid(x, y + 1, grid)) return true; // Down
  if (!isSolid(x - 1, y, grid)) return true; // Left
  return false;
}

Point[] traceSingleContour(int startX, int startY, int[][] grid, boolean[][] visited) {
  ArrayList<Point> path = new ArrayList<Point>();
  
  // Moore-Neighbor Tracing
  // 1. Start point B = (startX, startY)
  // 2. Backtrack to find entering empty pixel.
  // Poiché sappiamo che (startX, startY) è boundary, cerchiamo un vicino vuoto da cui "iniziare".
  // Diciamo che veniamo da WEST (sinistra) per default se stiamo scansionando da sinistra a destra.
  
  int currX = startX;
  int currY = startY;
  
  int cx = currX;
  int cy = currY;
  
  // Backtrack direction: cerchiamo un pixel VUOTO adiacente.
  // Ordine di check attorno a P: partiamo da quello da cui "siamo arrivati".
  // Scansione lineare trova il primo pixel. Quindi veniamo da sinistra (o sopra). 
  // Assumiamo che (x-1, y) sia vuoto o che (x,y) sia il primo.
  
  int backtrackDir = DIR_LEFT; // Pixel a sinistra
  if (isSolid(cx - 1, cy, grid)) backtrackDir = DIR_UP; // Se sinistra è pieno, prova su
  // ... semplice implementazione di Moore:
  
  path.add(new Point(cx, cy));
  visited[cx][cy] = true;
  
  // Il punto di partenza 'jacobs stopping criterion' è startX, startY AND entering direction.
  // Semplifichiamo: fermati quando torni a startX,startY.
  
  // Direzioni in senso orario: 0=Up, 1=Right, 2=Down, 3=Left
  int[] dx = {0, 1, 0, -1};
  int[] dy = {-1, 0, 1, 0};
  
  // Trova il primo vicino BLACKOUT (background) in senso orario partendo da backtrackdir
  // Questo definisce la "mano" sul muro.
  
  int enterDir = DIR_LEFT; // Assunzione scansione
  
  // Cerchiamo il primo pixel solido in senso ORARIO partendo dal background.
  // Moore neighbor: from backtrack, go clockwise until you hit a BLACK pixel. That is next P.
  
  // Partenza
  Point startP = new Point(cx, cy);
  Point currP = startP;
  
  // Trova un vicino vuoto iniziale per impostare correctly backtrack
  int checkDir = 0;
  // Cerca un background 'da cui arriviamo'.
  for(int d=0; d<4; d++){
      if (!isSolid(cx + dx[d], cy + dy[d], grid)) {
          enterDir = d; // Trovato un background a direzione d
          break;
      }
  }
  
  int maxSteps = 10000;
  int steps = 0;
  
  do {
      // Moore tracing step
      // enterDir punta al vicino VUOTO precedente.
      // Dobbiamo cercare il PROSSIMO PIXEL PIENO in senso ORARIO a partire da enterDir.
      
      boolean foundNext = false;
      
      // Controlliamo i vicini in senso orario partendo da enterDir
      // enterDir è il "vuoto". Quindi il pivot.
      for (int i = 0; i < 8; i++) { // Moore neighborhood usa 8, ma qui la grid è Manhattan?
          // Noodle usa connettività a 4 (su, giù, dx, sx).
          // Quindi usiamo solo 4 direzioni.
          
           // Partiamo da enterDir (che è vuoto) e giriamo orario finché non troviamo PIENO.
           int d = (enterDir + i) % 4;
           int nx = currP.x + dx[d];
           int ny = currP.y + dy[d];
           
           if (isSolid(nx, ny, grid)) {
               // Trovato il prossimo pixel del bordo!
               // Nuova posizione
               currP = new Point(nx, ny);
               path.add(currP);
               visited[nx][ny] = true;
               
               // La nuova enterDir (direzione da cui arriviamo al nuovo pixel, puntando al 'vuoto')
               // Il vicino (d-1) era vuoto (altrimenti l'avremmo preso).
               // Quindi il 'vuoto' relativo al nuovo pixel è la direzione opposta a d? No.
               // E' la direzione da cui veniamo "indietro" nel giro orario... 
               // Algoritmo: Enter direction for next step is (d + 2) % 4 (opposto) -> poi shift per trovare il primo vuoto?
               // Standard Moore: Backtrack = entry direction for next pixel.
               // La "entry direction" del prossimo pixel è quella che punta indietro al pixel vuoto adiacente.
               // L'ultimo pixel controllato che era VUOTO era (d - 1 + 4) % 4.
               // Relativo al nuovo pixel currP, quel pixel vuoto è in direzione ?
               // E' complicato in Manhattan. 
               
               // Semplificazione:
               // Ruota (d + 2) % 4 per puntare 'indietro' verso il pixel precedente
               // Poi -1 rotazione per partire a cercare dal 'fuori'.
               enterDir = (d + 3) % 4; // (d - 1) in senso antiorario -> (d + 3) % 4 in senso orario 0..3
               
               foundNext = true;
               break;
           }
      }
      
      if (!foundNext) break; // Isola di un solo pixel o errore
      
      steps++;
      if (steps > maxSteps) break;
      
  } while (currP.x != startP.x || currP.y != startP.y);
  
  Point[] res = new Point[path.size()];
  for(int i=0; i<path.size(); i++) res[i] = path.get(i);
  return res;
}
