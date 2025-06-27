import { Injectable, Logger } from '@nestjs/common';
import * as puppeteer from 'puppeteer';

@Injectable()
export class ValidacionService {
  private readonly logger = new Logger(ValidacionService.name);

  async validarAbogadoConPaginacion(matricula: string) {
    const browser = await puppeteer.launch({ headless: true, timeout: 120000 });
    const page = await browser.newPage();

    try {
      await page.goto(
        'https://app.funcionjudicial.gob.ec/ForoAbogados/Publico/frmConsultasGenerales.jsp',
        { waitUntil: 'domcontentloaded', timeout: 60000 }
      );

      const totalPaginas = 6000;

      for (let pagina = 1; pagina <= totalPaginas; pagina++) {
        this.logger.log(`🔍 Buscando en página ${pagina}`);

        // Cambiar el valor del input y hacer click en el botón de aceptar
        await page.evaluate((numeroPagina) => {
          const input = document.getElementById('txtNumeroPagina') as HTMLInputElement;
          if (input) input.value = String(numeroPagina);
        }, pagina);

        const botones = await page.$$('button');
        for (const boton of botones) {
          const img = await boton.$('img');
          if (img) {
            const src = await img.evaluate(el => el.getAttribute('src'));
            if (src && src.includes('accept.gif')) {
              await boton.click();
              break;
            }
          }
        }

        // Esperar respuesta del backend y renderización de tabla
        await page.waitForResponse(response =>
          response.url().includes('frmConsultasGenerales.jsp') && response.status() === 200,
          { timeout: 60000 }
        );

        await page.waitForSelector('table tbody tr');
        //await page.waitForTimeout(2000); // amortiguar lentitud del sitio

        // Evaluar si la matrícula buscada está presente
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
