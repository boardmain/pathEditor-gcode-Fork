#!/usr/bin/env python3
"""
Script per collegare tracciati concentrici G-code in modo continuo.

Riordina ciclicamente i punti di ogni tracciato per minimizzare la distanza
tra la fine di un tracciato e l'inizio del successivo.
"""

import re
import math
import sys
from typing import List, Tuple, Optional


class GCodePoint:
    """Rappresenta un punto G-code con coordinate e comando."""
    
    def __init__(self, x: float, y: float, z: Optional[float] = None, 
                 command: str = "G1", feedrate: Optional[int] = None):
        self.x = x
        self.y = y
        self.z = z
        self.command = command
        self.feedrate = feedrate
        
    def distance_to(self, other: 'GCodePoint') -> float:
        """Calcola la distanza euclidea 2D tra due punti."""
        return math.sqrt((self.x - other.x)**2 + (self.y - other.y)**2)
    
    def to_gcode(self) -> str:
        """Converte il punto in una linea G-code."""
        parts = [self.command]
        parts.append(f"X{self.x:.3f}")
        parts.append(f"Y{self.y:.3f}")
        if self.z is not None:
            parts.append(f"Z{self.z:.3f}")
        if self.feedrate is not None:
            parts.append(f"F{self.feedrate}")
        return " ".join(parts)


class GCodePath:
    """Rappresenta un tracciato completo (sequenza di punti)."""
    
    def __init__(self, points: List[GCodePoint]):
        self.points = points
        self.group_id = 1  # ID del gruppo a cui appartiene
        self.new_group = False  # True se questo path inizia un nuovo gruppo
        
    def find_closest_point_index(self, target: GCodePoint) -> int:
        """Trova l'indice del punto più vicino al target."""
        if not self.points:
            return 0
        
        min_dist = float('inf')
        min_idx = 0
        
        for i, point in enumerate(self.points):
            dist = point.distance_to(target)
            if dist < min_dist:
                min_dist = dist
                min_idx = i
                
        return min_idx
    
    def reorder_from_index(self, start_idx: int) -> 'GCodePath':
        """Riordina ciclicamente il path per iniziare dall'indice specificato."""
        if not self.points or start_idx == 0:
            new_path = GCodePath(self.points[:])
            new_path.group_id = self.group_id
            new_path.new_group = self.new_group
            return new_path
        
        # Rotazione ciclica: [0,1,2,3,4] con start_idx=2 -> [2,3,4,0,1]
        reordered = self.points[start_idx:] + self.points[:start_idx]
        new_path = GCodePath(reordered)
        new_path.group_id = self.group_id
        new_path.new_group = self.new_group
        return new_path
    
    def get_first_point(self) -> Optional[GCodePoint]:
        """Restituisce il primo punto del path."""
        return self.points[0] if self.points else None
    
    def get_last_point(self) -> Optional[GCodePoint]:
        """Restituisce l'ultimo punto del path."""
        return self.points[-1] if self.points else None


def parse_gcode_line(line: str, current_pos: dict) -> Tuple[Optional[GCodePoint], dict]:
    """
    Parsa una linea G-code ed estrae le coordinate.
    
    Args:
        line: Linea di G-code
        current_pos: Dizionario con la posizione corrente {x, y, z, f}
    
    Returns:
        Tupla (GCodePoint o None, posizione aggiornata)
    """
    line = line.strip()
    
    # Ignora commenti e linee vuote
    if not line or line.startswith(';'):
        return None, current_pos
    
    # Cerca comandi di movimento
    if line.startswith('G0') or line.startswith('G1'):
        command = line[:2]
        
        # Estrai coordinate
        x_match = re.search(r'X([-+]?\d*\.?\d+)', line)
        y_match = re.search(r'Y([-+]?\d*\.?\d+)', line)
        z_match = re.search(r'Z([-+]?\d*\.?\d+)', line)
        f_match = re.search(r'F(\d+)', line)
        
        # Aggiorna posizione corrente
        new_pos = current_pos.copy()
        if x_match:
            new_pos['x'] = float(x_match.group(1))
        if y_match:
            new_pos['y'] = float(y_match.group(1))
        if z_match:
            new_pos['z'] = float(z_match.group(1))
        if f_match:
            new_pos['f'] = int(f_match.group(1))
        
        # Crea punto se ha coordinate X e Y
        if 'x' in new_pos and 'y' in new_pos:
            point = GCodePoint(
                x=new_pos['x'],
                y=new_pos['y'],
                z=new_pos.get('z'),
                command=command,
                feedrate=new_pos.get('f')
            )
            return point, new_pos
    
    return None, current_pos


def extract_paths_from_gcode(gcode_lines: List[str]) -> Tuple[List[str], List[GCodePath], List[str]]:
    """
    Estrae i tracciati dal G-code.
    
    Un tracciato è identificato dal ciclo: pen up -> move to position -> pen down -> drawing -> pen up
    
    Returns:
        Tupla (header_lines, paths, footer_lines)
    """
    header = []
    footer = []
    paths = []
    current_path_points = []
    current_pos = {}
    
    in_header = True
    in_path = False
    first_movement_found = False
    pen_is_down = False
    
    for line in gcode_lines:
        stripped = line.strip()
        
        # Identifica quando la penna si alza o si abbassa
        if re.search(r'G0?\s+Z', stripped):
            z_match = re.search(r'Z([-+]?\d*\.?\d+)', stripped)
            if z_match:
                z_val = float(z_match.group(1))
                
                if z_val > 0 and not pen_is_down:
                    # Pen down - inizia un nuovo path
                    pen_is_down = True
                    in_path = True
                    in_header = False
                    first_movement_found = True
                    
                elif z_val <= 0.1 and pen_is_down:
                    # Pen up - termina il path corrente
                    pen_is_down = False
                    in_path = False
                    if current_path_points:
                        paths.append(GCodePath(current_path_points))
                        print(f"  Path estratto con {len(current_path_points)} punti")
                        current_path_points = []
        
        # Parsa i punti nel path corrente (solo con pen down)
        if pen_is_down and in_path:
            if re.search(r'^G[01]\s+.*[XY]', stripped):
                point, current_pos = parse_gcode_line(stripped, current_pos)
                if point:
                    current_path_points.append(point)
        
        # Raccogli header e footer
        if in_header:
            header.append(line)
        elif not in_path and first_movement_found and not pen_is_down:
            footer.append(line)
    
    # Aggiungi ultimo path se presente
    if current_path_points:
        paths.append(GCodePath(current_path_points))
        print(f"  Path estratto con {len(current_path_points)} punti")
    
    return header, paths, footer


def connect_paths(paths: List[GCodePath], max_group_distance: float = 15.0) -> List[GCodePath]:
    """
    Collega i tracciati riordinandoli per minimizzare le distanze.
    
    Usa l'algoritmo "Nearest Neighbor" con raggruppamento automatico:
    1. Parte dal primo path
    2. Per ogni step, cerca tra tutti i path rimanenti quello con il punto
       più vicino alla fine del path corrente
    3. Se la distanza è minore di max_group_distance, fa parte dello stesso gruppo
       e viene collegato senza alzare la penna
    4. Se la distanza è maggiore, inizia un nuovo gruppo (penna alzata)
    
    Args:
        paths: Lista di path da collegare
        max_group_distance: Distanza massima (mm) per considerare path dello stesso gruppo
    """
    if not paths:
        return []
    
    # Lista dei path rimanenti da visitare
    remaining_paths = list(paths)
    
    # Inizia con il primo path
    connected_paths = [remaining_paths.pop(0)]
    # Marca il primo path come appartenente al gruppo 1
    connected_paths[0].group_id = 1
    connected_paths[0].new_group = True
    
    first = connected_paths[0].get_first_point()
    last = connected_paths[0].get_last_point()
    print(f"\nGruppo 1 - Path 1: primo punto ({first.x:.3f}, {first.y:.3f}), ultimo punto ({last.x:.3f}, {last.y:.3f})")
    
    path_counter = 2
    current_group = 1
    
    while remaining_paths:
        # Ultimo punto del path corrente
        last_point = connected_paths[-1].get_last_point()
        
        if not last_point:
            # Se non c'è un ultimo punto, prendi il prossimo path disponibile
            path = remaining_paths.pop(0)
            current_group += 1
            path.group_id = current_group
            path.new_group = True
            connected_paths.append(path)
            continue
        
        # Trova il path con il punto più vicino tra tutti i rimanenti
        best_path_idx = None
        best_point_idx = None
        best_distance = float('inf')
        
        for path_idx, candidate_path in enumerate(remaining_paths):
            if not candidate_path.points:
                continue
            
            # Trova il punto più vicino in questo path
            closest_idx = candidate_path.find_closest_point_index(last_point)
            closest_point = candidate_path.points[closest_idx]
            distance = last_point.distance_to(closest_point)
            
            # È il migliore finora?
            if distance < best_distance:
                best_distance = distance
                best_path_idx = path_idx
                best_point_idx = closest_idx
        
        # Se abbiamo trovato un path valido
        if best_path_idx is not None:
            # Rimuovi il path scelto dalla lista dei rimanenti
            chosen_path = remaining_paths.pop(best_path_idx)
            
            # Determina se appartiene allo stesso gruppo o inizia un nuovo gruppo
            if best_distance > max_group_distance:
                current_group += 1
                chosen_path.new_group = True
                print(f"\n>>> NUOVO GRUPPO {current_group} (distanza {best_distance:.1f}mm > {max_group_distance}mm)")
            else:
                chosen_path.new_group = False
            
            chosen_path.group_id = current_group
            
            print(f"\nGruppo {current_group} - Path {path_counter}:")
            print(f"  Path precedente termina a: ({last_point.x:.3f}, {last_point.y:.3f})")
            print(f"  Punto più vicino trovato all'indice {best_point_idx}/{len(chosen_path.points)-1}")
            print(f"  Punto più vicino: ({chosen_path.points[best_point_idx].x:.3f}, {chosen_path.points[best_point_idx].y:.3f})")
            print(f"  Distanza di connessione: {best_distance:.3f}mm")
            
            # Riordina il path per iniziare dal punto più vicino
            reordered_path = chosen_path.reorder_from_index(best_point_idx)
            reordered_path.group_id = chosen_path.group_id
            reordered_path.new_group = chosen_path.new_group
            connected_paths.append(reordered_path)
            
            # Verifica
            first_point = reordered_path.get_first_point()
            last_point_new = reordered_path.get_last_point()
            if first_point:
                print(f"  Path riordinato inizia da: ({first_point.x:.3f}, {first_point.y:.3f})")
                print(f"  Path riordinato termina a: ({last_point_new.x:.3f}, {last_point_new.y:.3f})")
            
            path_counter += 1
        else:
            # Fallback: prendi il prossimo disponibile
            path = remaining_paths.pop(0)
            current_group += 1
            path.group_id = current_group
            path.new_group = True
            connected_paths.append(path)
            path_counter += 1
    
    return connected_paths


def generate_gcode(header: List[str], paths: List[GCodePath], 
                   footer: List[str], pen_up: float = 0.0, 
                   pen_down: float = 5.2) -> List[str]:
    """
    Genera il G-code completo dai path collegati.
    
    Args:
        header: Linee di intestazione
        paths: Tracciati collegati
        footer: Linee di chiusura
        pen_up: Valore Z per penna alzata
        pen_down: Valore Z per penna abbassata
    """
    lines = []
    
    # Aggiungi header
    for line in header:
        lines.append(line.rstrip())
    
    for i, path in enumerate(paths):
        if not path.points:
            continue
        
        first_point = path.get_first_point()
        
        lines.append("")
        lines.append(f"; --- Gruppo {path.group_id} - Path {i+1} ({len(path.points)} points) ---")
        
        # Se questo path inizia un nuovo gruppo, alza la penna, muoviti, abbassa la penna
        if i == 0 or path.new_group:
            lines.append(f"G0 Z{pen_up} ; pen up")
            lines.append(f"G0 X{first_point.x:.3f} Y{first_point.y:.3f} ; Move to next group")
            lines.append(f"G0 Z{pen_down} ; pen down")
            
            # Ottieni feedrate dal primo punto se disponibile
            if i == 0:
                feedrate = None
                for point in path.points:
                    if point.feedrate:
                        feedrate = point.feedrate
                        break
                
                if feedrate:
                    lines.append(f"F{feedrate} ; Linear speed")
        else:
            # Path dello stesso gruppo: connessione continua con G1 (senza alzare la penna)
            lines.append(f"; Connessione continua dal path precedente")
            # Collega al secondo punto del path successivo (se esiste) saltando il primo
            if len(path.points) > 1:
                second_point = path.points[1]
                lines.append(f"G1 X{second_point.x:.3f} Y{second_point.y:.3f} ; Connessione al secondo punto")
                start_idx = 2  # Inizia dal terzo punto
            else:
                lines.append(f"G1 X{first_point.x:.3f} Y{first_point.y:.3f}")
                start_idx = 1  # Path troppo corto, usa comportamento normale
        
        # Disegna tutti i punti del path (partendo da start_idx se definito)
        if i == 0 or path.new_group:
            start_idx = 0  # Per i nuovi gruppi disegna tutti i punti
        
        for j in range(start_idx, len(path.points)):
            point = path.points[j]
            lines.append(f"G1 X{point.x:.3f} Y{point.y:.3f}")
    
    # Penna alzata solo alla fine di tutti i path
    lines.append("")
    lines.append(f"G0 Z{pen_up} ; pen up")
    lines.append("")
    
    # Aggiungi footer
    for line in footer:
        lines.append(line.rstrip())
    
    return lines


def process_gcode_file(input_file: str, output_file: str):
    """
    Processa un file G-code collegando i tracciati concentrici.
    """
    print(f"Lettura file: {input_file}")
    
    # Leggi il file
    with open(input_file, 'r') as f:
        gcode_lines = f.readlines()
    
    print(f"Totale linee: {len(gcode_lines)}")
    
    # Estrai i tracciati
    print("Estrazione tracciati...")
    header, paths, footer = extract_paths_from_gcode(gcode_lines)
    
    print(f"Trovati {len(paths)} tracciati")
    print(f"Header: {len(header)} linee")
    print(f"Footer: {len(footer)} linee")
    
    # Collega i tracciati
    print("\nCollegamento tracciati...")
    connected_paths = connect_paths(paths)
    
    # Genera nuovo G-code
    print("\nGenerazione G-code...")
    new_gcode = generate_gcode(header, connected_paths, footer)
    
    # Scrivi il file di output
    with open(output_file, 'w') as f:
        f.write('\n'.join(new_gcode))
    
    print(f"\nFile salvato: {output_file}")
    print(f"Totale linee generate: {len(new_gcode)}")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Uso: python connect_paths.py <file_input.gcode> [file_output.gcode]")
        print("Esempio: python connect_paths.py test.gcode test_connected.gcode")
        sys.exit(1)
    
    input_file = sys.argv[1]
    output_file = sys.argv[2] if len(sys.argv) > 2 else input_file.replace('.gcode', '_connected.gcode')
    
    try:
        process_gcode_file(input_file, output_file)
    except Exception as e:
        print(f"Errore: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
