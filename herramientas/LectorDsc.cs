// Lector de archivos .dsc (scripts de las canciones) de Project DIVA Future Tone / Mega Mix+.
// Solo lee los comandos LYRIC (qué línea de letra se muestra y cuándo).
//
// La tabla de comandos y cantidad de argumentos es la del formato Future Tone, documentada en el
// editor de DSC de nastys (https://github.com/nastys/nastys.github.io, dsceditor/db_ft.js) y usada
// también por LyricGen de Aura39 (https://github.com/Aura39/LyricGen). Este código es propio.
using System;
using System.Collections.Generic;
using System.IO;

namespace SpanishLyrics
{
    public class LineaDsc
    {
        public int Indice;     // número de línea en el pv_db (pv_XXX.lyric.NNN)
        public double Inicio;  // segundos
        public double Fin;     // segundos (o -1 si no hay comando que la borre)
    }

    public static class LectorDsc
    {
        const int TIME = 1;
        const int LYRIC = 24;

        // Cantidad de argumentos de cada comando (índice = número de comando)
        static readonly int[] Argumentos = BuildTabla();

        static int[] BuildTabla()
        {
            int[,] pares = {
                {0,0},{1,1},{2,4},{3,2},{4,2},{5,2},{6,7},{7,4},{8,2},{9,6},{10,2},{11,1},{12,6},{13,2},{14,1},
                {15,1},{16,3},{17,2},{18,3},{19,5},{20,5},{21,4},{22,4},{23,5},{24,2},{25,0},{26,2},{27,4},{28,2},
                {29,2},{30,1},{31,21},{32,0},{33,3},{34,2},{35,5},{36,1},{37,1},{38,7},{39,1},{40,1},{41,2},{42,1},
                {43,2},{44,1},{45,2},{46,3},{47,3},{48,1},{49,2},{50,2},{51,3},{52,6},{53,6},{54,1},{55,1},{56,2},
                {57,3},{58,1},{59,2},{60,2},{61,4},{62,4},{63,1},{64,2},{65,1},{66,2},{67,1},{68,1},{69,3},{70,3},
                {71,3},{72,2},{73,1},{74,9},{75,3},{76,2},{77,4},{78,2},{79,3},{80,2},{81,24},{82,1},{83,2},{84,1},
                {85,3},{86,1},{87,3},{88,4},{89,1},{90,2},{91,6},{92,3},{93,2},{94,3},{95,3},{96,4},{97,1},{98,1},
                {99,3},{100,3},{101,4},{102,2},{103,3},{104,3},{105,8},{106,2}
            };
            var tabla = new int[107];
            for (int i = 0; i < tabla.Length; i++) tabla[i] = -1;
            for (int i = 0; i < pares.GetLength(0); i++) tabla[pares[i, 0]] = pares[i, 1];
            return tabla;
        }

        /// <summary>
        /// Devuelve las líneas de letra con sus tiempos, ordenadas por inicio.
        /// Devuelve null si el archivo no es un DSC de Future Tone que se pueda leer completo.
        /// </summary>
        public static List<LineaDsc> LeerLetras(string ruta)
        {
            byte[] datos = File.ReadAllBytes(ruta);
            if (datos.Length < 8 || datos.Length % 4 != 0) return null;
            int formato = BitConverter.ToInt32(datos, 0);
            // Los formatos de Future Tone/Arcade empiezan con una fecha en hexadecimal (por ejemplo 0x14050921).
            // "PVSC" (F 2nd / X) usa otra tabla de comandos y no se lee.
            if (formato == 0x43535650) return null;

            var lineas = new List<LineaDsc>();
            LineaDsc abierta = null;
            long tiempo = 0;
            int pos = 4;
            while (pos + 4 <= datos.Length)
            {
                int comando = BitConverter.ToInt32(datos, pos);
                pos += 4;
                if (comando < 0 || comando >= Argumentos.Length || Argumentos[comando] < 0) return null;
                int n = Argumentos[comando];
                if (pos + n * 4 > datos.Length) return null;
                if (comando == TIME)
                {
                    tiempo = BitConverter.ToInt32(datos, pos);
                }
                else if (comando == LYRIC)
                {
                    int indice = BitConverter.ToInt32(datos, pos);
                    double segundos = tiempo / 100000.0;
                    if (abierta != null && abierta.Fin < 0) abierta.Fin = segundos;
                    if (indice > 0)
                    {
                        abierta = new LineaDsc { Indice = indice, Inicio = segundos, Fin = -1 };
                        lineas.Add(abierta);
                    }
                    else abierta = null;
                }
                else if (comando == 0) break; // END
                pos += n * 4;
            }
            lineas.Sort((a, b) => a.Inicio.CompareTo(b.Inicio));
            return lineas;
        }
    }
}
