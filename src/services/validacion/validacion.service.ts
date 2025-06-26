import { Injectable, Logger } from '@nestjs/common';
import * as puppeteer from 'puppeteer';

@Injectable()
export class ValidacionService {
  private readonly logger = new Logger(ValidacionService.name);

  async validarAbogadoConPaginacion(matricula: string) {
    const browser = await puppeteer.launch({ headless: true });
    const page = await browser.newPage();

    try {
      await page.goto(
        'https://app.funcionjudicial.gob.ec/ForoAbogados/Publico/frmConsultasGenerales.jsp',
        { waitUntil: 'domcontentloaded' }
      );

      const totalPaginas = 6000;

      for (let pagina = 1; pagina <= totalPaginas; pagina++) {
        this.logger.log(`🔍 Buscando en página ${pagina}`);

        // Cambiar manualmente al número de página
        await page.evaluate((numeroPagina) => {
          const inputPagina = document.getElementById('txtNumeroPagina') as HTMLInputElement;
          if (inputPagina) {
            inputPagina.value = String(numeroPagina);
          }
        }, pagina);

        // Click en el botón con el icono verde para avanzar a esa página
        const botones = await page.$$('button');
        for (const boton of botones) {
          const img = await boton.$('img');
          if (img) {
            const alt = await img.evaluate(el => el.getAttribute('src'));
            if (alt && alt.includes('accept.gif')) {
              // Captura matrícula de la primera fila antes del cambio
              const anteriorPrimeraMatricula = await page.evaluate(() => {
                const primeraFila = document.querySelector('table tbody tr');
                const columnas = primeraFila?.querySelectorAll('td');
                return columnas && columnas.length > 2 ? columnas[2].innerText.trim() : null;
              });

              await boton.click();

              // Espera hasta que cambie la matrícula visible en la primera fila (indicando que cambió la página)
              await page.waitForFunction((anteriorMatricula) => {
                const primeraFila = document.querySelector('table tbody tr');
                const columnas = primeraFila?.querySelectorAll('td');
                const nuevaMatricula = columnas && columnas.length > 2 ? columnas[2].innerText.trim() : null;
                return nuevaMatricula !== anteriorMatricula;
              }, {}, anteriorPrimeraMatricula);

              break;
            }
          }
        }

        const resultado = await page.evaluate((matriculaBuscada) => {
          const filas = Array.from(document.querySelectorAll('table tbody tr'));
          for (const fila of filas) {
            const columnas = fila.querySelectorAll('td');
            if (columnas.length < 6) continue;
            const mat = columnas[2].innerText.trim();
            if (mat === matriculaBuscada) {
              return {
                nombres: columnas[3].innerText.trim(),
                direccion_estudio: columnas[4].innerText.trim(),
                fecha_inscripcion: columnas[5].innerText.trim(),
                credencial: columnas[6].innerText.trim(),
                estado: columnas[7].innerText.trim()
              };
            }
          }
          return null;
        }, matricula);

        if (resultado) {
          await browser.close();
          return {
            valido: true,
            matricula,
            nombres: resultado.nombres,
            direccion_estudio: resultado.direccion_estudio,
            fecha_inscripcion: resultado.fecha_inscripcion,
            credencial: resultado.credencial,
            estado: resultado.estado,
            fecha_validacion: new Date().toISOString(),
            fuente: 'FORO_ABOGADOS'
          };
        }
      }

      await browser.close();
      return {
        valido: false,
        matricula,
        motivo: 'Abogado no encontrado en el Foro de Abogados',
        fecha_validacion: new Date().toISOString(),
        fuente: 'FORO_ABOGADOS'
      };
    } catch (error) {
      this.logger.error(`Error validando abogado: ${error.message}`);
      await browser.close();
      return {
        valido: false,
        matricula,
        error: 'Error en proceso de validación',
        message: error.message,
        fecha_validacion: new Date().toISOString(),
        fuente: 'FORO_ABOGADOS_ERROR'
      };
    }
  }
}
