# Fixtures anonimizados de importación

Todos los archivos de esta carpeta son datos sintéticos versionados. No proceden de cuentas reales y no contienen IBAN, nombres de titulares, direcciones reales ni saldos de producción.

| Fixture | Formato | Casos cubiertos |
| --- | --- | --- |
| `anonymous_openbank_csv.csv` | CSV separado por `;` | Ingresos/gastos, dirección sintética, fila inválida y filas repetidas |
| `anonymous_cajamar_csv.csv` | CSV separado por `;` | Cabeceras Cajamar, ingresos/gastos y error parcial |
| `anonymous_abanca_csv.csv` | CSV separado por `;` | Cabeceras ABANCA, ingresos/gastos y error parcial |
| `anonymous_openbank_xlsx.xlsx` | XLSX OOXML | Hoja bancaria, importe europeo, dirección sintética y error parcial |
| `anonymous_openbank_pdf.pdf` | PDF Openbank | Columnas de fecha/importe/saldo y movimientos en ambas direcciones |

Los nombres de comercios, conceptos y direcciones usan el sufijo `DEMO` o `PRUEBA` deliberadamente. Los tests acceden a estos archivos desde el árbol de fuentes para que sigan siendo reproducibles tanto en Xcode como en CI.
