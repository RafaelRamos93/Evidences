#!/bin/bash

# Iniciar tiempo de ejecución
INICIO=$(date +%s)

# Definir el directorio a analizar, usa PWD si no se proporciona un argumento
DIRECTORIO="${1:-$(pwd)}"
SALIDA_JSON="reporte_warnings.json"

# Expresión regular para detectar warnings con número (ejemplo: WARNING 301: mensaje)
PATRON_WARNING="(WARNING|Warning|warning) ([0-9]+) : (.+)"
# Expresión regular para detectar fin del mensaje (6 dígitos numéricos al inicio o línea que empieza con *)
PATRON_FIN="^[[:space:]]*([0-9]{6}|\*)"

# Inicializar estructura JSON
echo "{" > "$SALIDA_JSON"
echo "  \"directorio\": \"$(realpath "$DIRECTORIO")\"," >> "$SALIDA_JSON"
echo "  \"archivos\": [" >> "$SALIDA_JSON"

ARCHIVOS_PROCESADOS=0
TOTAL_GLOBAL_WARNINGS=0

# Procesar cada archivo .txt en el directorio
for archivo in "$DIRECTORIO"/*.txt; do
    if [[ -f "$archivo" ]]; then
        ((ARCHIVOS_PROCESADOS++))
        echo "    {" >> "$SALIDA_JSON"
        echo "      \"nombre\": \"$(basename "$archivo")\"," >> "$SALIDA_JSON"
        echo "      \"warnings\": [" >> "$SALIDA_JSON"

        WARNINGS_ENCONTRADOS=0
        WARNINGS_JSON=""
        LEYENDO_WARNING=0  # Bandera para detectar contenido multi-línea
        MENSAJE_WARNING="" # Acumulador del mensaje multi-línea
        CATEGORIA_ACTUAL=""
        LINEA_INICIO=0

        # Diccionario asociativo para contar warnings por categoría en este archivo
        declare -A WARNINGS_POR_CATEGORIA

        # Leer el archivo línea por línea con contador
        LINE_NUM=0
        while IFS= read -r linea || [[ -n "$linea" ]]; do
            ((LINE_NUM++))  # Contador de línea
            LINEA_LIMPIA="$(echo "$linea" | sed 's/^[[:space:]]*//')"  # Eliminar espacios iniciales

            # Revisar si la línea es un warning que coincida con el patrón
            if [[ "$LINEA_LIMPIA" =~ $PATRON_WARNING ]]; then
                # Si ya estábamos leyendo un warning, guardamos el anterior
                if [[ $LEYENDO_WARNING -eq 1 ]]; then
                    # Añadir el warning al JSON
                    WARNINGS_JSON+="        { \"linea\": $LINEA_INICIO, \"categoria\": \"$CATEGORIA_ACTUAL\", \"mensaje\": \"$(echo -e "$MENSAJE_WARNING" | sed ':a;N;$!ba;s/\n/\\n/g')\" },\n"
                    ((WARNINGS_POR_CATEGORIA["$CATEGORIA_ACTUAL"]++))
                fi

                # Iniciar captura de un nuevo warning
                LEYENDO_WARNING=1
                LINEA_INICIO=$LINE_NUM
                CATEGORIA_ACTUAL="${BASH_REMATCH[2]}"
                MENSAJE_WARNING="${BASH_REMATCH[3]}"
            
            # Si ya estamos leyendo un warning y no es el final, continuamos el mensaje
            elif [[ $LEYENDO_WARNING -eq 1 ]]; then
                if [[ "$LINEA_LIMPIA" =~ $PATRON_FIN ]]; then
                    # Si encontramos un patrón de fin, terminamos este warning
                    WARNINGS_JSON+="        { \"linea\": $LINEA_INICIO, \"categoria\": \"$CATEGORIA_ACTUAL\", \"mensaje\": \"$(echo -e "$MENSAJE_WARNING" | sed ':a;N;$!ba;s/\n/\\n/g')\" },\n"
                    ((WARNINGS_POR_CATEGORIA["$CATEGORIA_ACTUAL"]++))
                    LEYENDO_WARNING=0
                else
                    MENSAJE_WARNING+="\n$linea"
                fi
            fi
        done < "$archivo"

        # Si el archivo termina con un warning abierto, lo guardamos
        if [[ $LEYENDO_WARNING -eq 1 ]]; then
            WARNINGS_JSON+="        { \"linea\": $LINEA_INICIO, \"categoria\": \"$CATEGORIA_ACTUAL\", \"mensaje\": \"$(echo -e "$MENSAJE_WARNING" | sed ':a;N;$!ba;s/\n/\\n/g')\" },\n"
            ((WARNINGS_POR_CATEGORIA["$CATEGORIA_ACTUAL"]++))
        fi

        for categoria in "${!WARNINGS_POR_CATEGORIA[@]}"; do
            ((TOTAL_GLOBAL_WARNINGS+=WARNINGS_POR_CATEGORIA["$categoria"]))
            ((WARNINGS_ENCONTRADOS+=WARNINGS_POR_CATEGORIA["$categoria"]))
        done

        if [[ $WARNINGS_ENCONTRADOS -gt 0 ]]; then
            WARNINGS_JSON=$(echo -e "$WARNINGS_JSON" | sed '$ s/,$//')
        fi

        echo -e "$WARNINGS_JSON" >> "$SALIDA_JSON"
        echo "      ]," >> "$SALIDA_JSON"

        echo "      \"totales_por_categoria\": {" >> "$SALIDA_JSON"
        for categoria in "${!WARNINGS_POR_CATEGORIA[@]}"; do
            echo "        \"$categoria\": ${WARNINGS_POR_CATEGORIA[$categoria]}," >> "$SALIDA_JSON"
        done
        sed -i '$ s/,$//' "$SALIDA_JSON"

        echo "      }," >> "$SALIDA_JSON"
        echo "      \"total_warnings\": $WARNINGS_ENCONTRADOS" >> "$SALIDA_JSON"
        echo "    }," >> "$SALIDA_JSON"
    fi
done

if [[ $ARCHIVOS_PROCESADOS -gt 0 ]]; then
    sed -i '$ s/,$//' "$SALIDA_JSON"
fi

echo "  ]," >> "$SALIDA_JSON"
echo "  \"resumen_global\": {" >> "$SALIDA_JSON"
echo "    \"total_warnings\": $TOTAL_GLOBAL_WARNINGS" >> "$SALIDA_JSON"
echo "  }" >> "$SALIDA_JSON"
echo "}" >> "$SALIDA_JSON"

# Calcular tiempo de ejecución
FIN=$(date +%s)
TIEMPO_TOTAL=$((FIN - INICIO))

echo "Reporte generado: $SALIDA_JSON"
echo "Tiempo de ejecución: $TIEMPO_TOTAL segundos"
