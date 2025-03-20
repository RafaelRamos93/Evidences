#!/bin/bash

# Definir el directorio a analizar, usa PWD si no se proporciona un argumento
DIRECTORIO="${1:-$(pwd)}"
SALIDA_JSON="reporte_warnings.json"

# Expresión regular para detectar warnings con número (ejemplo: WARNING 301: mensaje)
PATRON_WARNING="(WARNING|Warning|warning) ([0-9]+): (.+)"

# Inicializar estructura JSON
echo "{" > "$SALIDA_JSON"
echo "  \"directorio\": \"$(realpath "$DIRECTORIO")\"," >> "$SALIDA_JSON"
echo "  \"archivos\": [" >> "$SALIDA_JSON"

# Diccionario asociativo para contar warnings por categoría
declare -A WARNINGS_POR_CATEGORIA
TOTAL_WARNINGS=0
ARCHIVOS_PROCESADOS=0

# Procesar cada archivo .txt en el directorio
for archivo in "$DIRECTORIO"/*.txt; do
    if [[ -f "$archivo" ]]; then
        ((ARCHIVOS_PROCESADOS++))
        echo "    {" >> "$SALIDA_JSON"
        echo "      \"nombre\": \"$(basename "$archivo")\"," >> "$SALIDA_JSON"
        echo "      \"warnings\": [" >> "$SALIDA_JSON"

        WARNINGS_ENCONTRADOS=0
        WARNINGS_JSON=""

        # Leer el archivo línea por línea
        while IFS= read -r linea || [[ -n "$linea" ]]; do
            if [[ "$linea" =~ $PATRON_WARNING ]]; then
                numero_linea=$(grep -n "$linea" "$archivo" | cut -d: -f1)
                categoria_warning="${BASH_REMATCH[2]}"
                mensaje_warning=$(echo "${BASH_REMATCH[3]}" | sed 's/"/\\"/g')  # Escapar comillas para JSON
                
                # Contar este tipo de warning
                ((WARNINGS_POR_CATEGORIA["$categoria_warning"]++))
                ((TOTAL_WARNINGS++))

                # Construir JSON del warning
                WARNINGS_JSON+="        { \"linea\": $numero_linea, \"categoria\": \"$categoria_warning\", \"mensaje\": \"$mensaje_warning\" },\n"
                ((WARNINGS_ENCONTRADOS++))
            fi
        done < "$archivo"

        # Eliminar la última coma del JSON de warnings si hubo al menos uno
        if [[ $WARNINGS_ENCONTRADOS -gt 0 ]]; then
            WARNINGS_JSON=$(echo -e "$WARNINGS_JSON" | sed '$ s/,$//')
        fi

        # Agregar los warnings al JSON
        echo -e "$WARNINGS_JSON" >> "$SALIDA_JSON"
        echo "      ]" >> "$SALIDA_JSON"
        echo "    }," >> "$SALIDA_JSON"
    fi
done

# Eliminar la última coma en la lista de archivos si hubo al menos uno
if [[ $ARCHIVOS_PROCESADOS -gt 0 ]]; then
    sed -i '$ s/,$//' "$SALIDA_JSON"
fi

echo "  ]," >> "$SALIDA_JSON"

# Agregar la tabla de totales por categoría
echo "  \"totales_por_categoria\": {" >> "$SALIDA_JSON"
for categoria in "${!WARNINGS_POR_CATEGORIA[@]}"; do
    echo "    \"$categoria\": ${WARNINGS_POR_CATEGORIA[$categoria]}," >> "$SALIDA_JSON"
done
# Eliminar la última coma de la tabla de totales por categoría si hubo al menos uno
sed -i '$ s/,$//' "$SALIDA_JSON"

echo "  }," >> "$SALIDA_JSON"

# Agregar el total de warnings detectados
echo "  \"total_warnings\": $TOTAL_WARNINGS" >> "$SALIDA_JSON"

echo "}" >> "$SALIDA_JSON"

echo "Reporte generado: $SALIDA_JSON"
