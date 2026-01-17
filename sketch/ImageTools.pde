
void importImageShape() {
  selectInput("Seleziona un'immagine (JPG/PNG) da usare come forma:", "onShapeSelected");
}

void onShapeSelected(File selection) {
  if (selection == null) {
    println("Nessuna immagine selezionata.");
    return;
  }
  
  println("Caricamento immagine forma: " + selection.getAbsolutePath());
  PImage img = loadImage(selection.getAbsolutePath());
  
  if (img != null) {
    applyShapeToGrid(img);
  }
}

void applyShapeToGrid(PImage sourceImg) {
  // Crea una copia per non modificare l'originale se servisse
  PImage img = sourceImg.copy();
  
  // 1. Ridimensioniamo l'immagine per combaciare esattamente con la griglia del sistema
  img.resize(GRID_W, GRID_H);
  img.loadPixels();
  
  // 2. Aggiorniamo le celle
  // Logica: Vogliamo riempire la FORMA.
  // Assumiamo:
  // - Pixel SCURO (forma) -> Area LIBERA (disegnabile) -> CellType.EMPTY
  // - Pixel CHIARO (sfondo) -> Area BLOCCATA (bordo) -> CellType.BLACKOUT
  
  float threshold = 128; 
  
  for (int x = 0; x < GRID_W; x++) {
    for (int y = 0; y < GRID_H; y++) {
      // Ottieni il colore del pixel corrispondente alla cella
      int index = x + y * img.width;
      
      // Controllo bounds per sicurezza
      if (index < img.pixels.length) {
        color c = img.pixels[index];
        
        // Se è chiaro (sfondo), lo blocchiamo.
        // Se è scuro (forma), lo lasciamo libero.
        if (brightness(c) > threshold) {
           blackoutCells[x][y] = CellType.BLACKOUT;
        } else {
           blackoutCells[x][y] = CellType.EMPTY;
        }
      }
    }
  }
  
  println("Immagine forma applicata. Reset della generazione...");
  // Reimposta la generazione per creare noodles dentro la nuova forma
  useSmartFill = true;
  reset();
  useSmartFill = false; // Reset per future chiamate manuali con 'r', se desiderato
}
