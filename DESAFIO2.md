# Desafío DevOpsII: Sistema de Gestión de Autos

## Objetivo
Crear un script de automatización para un pipeline de CI/CD que prepare, construya y despliegue una aplicación web simple.

## Contexto
Eres un ingeniero DevOps trabajando en una startup que desarrolla una aplicación web. Tu tarea es crear un script que automatice el proceso de obtención de información del proyecto, construcción de la imagen Docker y preparación para el despliegue.

## Requisitos

1. **Script de Automatización**
   - Crea un script en Bash llamado `ci_cd_automation.sh`.
   - El script debe realizar las siguientes tareas:
     a. Obtener la versión actual del proyecto (de package.json, CHANGELOG.md o Git tags).
     b. Obtener el nombre del repositorio y la rama actual.
     c. Construir el nombre de la imagen Docker basado en el repositorio y la versión.
     d. Obtener información del último commit (autor y correo electrónico).
     e. Verificar si las herramientas necesarias (git, docker, jq) están instaladas.

2. **Construcción de Imagen Docker**
   - Incluir comandos para construir la imagen Docker de la aplicación.
   - Etiquetar la imagen con la versión obtenida y "latest".

3. **Simulación de Despliegue**
   - Agregar comandos que simulen el despliegue de la aplicación (por ejemplo, ejecutar el contenedor localmente).

4. **Logging y Salida**
   - El script debe proporcionar salidas claras y coloridas en la consola.
   - Debe generar un archivo de log con toda la información recopilada y las acciones realizadas.

5. **Manejo de Errores**
   - Implementar manejo básico de errores (por ejemplo, si falta alguna herramienta requerida).

6. **Documentación**
   - Incluir comentarios en el script explicando cada sección.
   - Crear un README.md con instrucciones sobre cómo usar el script.

## Retos Adicionales (Opcional)

7. **Parametrización**
   - Permitir que el usuario especifique el registro Docker y el puerto de la aplicación como parámetros.

8. **Integración con un Servicio de CI**
   - Proporcionar un archivo de configuración básico para integrar este script en un servicio de CI (por ejemplo, .gitlab-ci.yml o .github/workflows/ci.yml).

9. **Pruebas**
   - Agregar un paso que ejecute pruebas básicas en el contenedor antes de considerarlo listo para despliegue.

## Entregables

1. Script `ci_cd_automation.sh`
2. Dockerfile para la aplicación web
3. README.md con instrucciones
4. (Opcional) Archivo de configuración para CI

## Criterios de Evaluación

- Funcionalidad: El script debe ejecutarse sin errores y realizar todas las tareas especificadas.
- Legibilidad: Código bien organizado y comentado.
- Robustez: Manejo adecuado de errores y casos extremos.
- Documentación: README claro y completo.