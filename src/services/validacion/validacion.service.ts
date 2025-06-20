import { Injectable, Logger, BadRequestException, HttpException, HttpStatus, Inject } from '@nestjs/common';
import { HttpService } from '@nestjs/axios';
import { ConfigService } from '@nestjs/config';
import { Cache } from 'cache-manager';
import { CACHE_MANAGER } from '@nestjs/cache-manager';
import { firstValueFrom } from 'rxjs';
import * as cheerio from 'cheerio';
import { ValidarAbogadoDto } from './dto/validar-abogado.dto';

// Interfaces para tipado correcto
interface AbogadoEncontrado {
  matricula: string;
  nombres: string;
  direccion_estudio: string;
  fecha_inscripcion: string;
  credencial: string;
  estado: string;
}

export interface ValidacionResult {
  valido: boolean;
  matricula: string;
  nombres?: string;
  cedula?: string | null;
  estado?: string;
  fecha_inscripcion?: string;
  direccion_estudio?: string;
  credencial?: string;
  fecha_validacion: string;
  fuente: string;
  motivo?: string;
  sugerencia?: string;
  error?: string;
  message?: string;
}

@Injectable()
export class ValidacionService {
  private readonly logger = new Logger(ValidacionService.name);

  constructor(
    private readonly httpService: HttpService,
    private readonly configService: ConfigService,
    @Inject(CACHE_MANAGER) private cacheManager: Cache,
  ) {}

  // ================================================
  // VALIDACIÓN DE ABOGADOS - SIEMPRE CONSULTA REAL
  // ================================================

  async validarAbogado(validarAbogadoDto: ValidarAbogadoDto): Promise<ValidacionResult> {
    const cacheKey = `abogado_${validarAbogadoDto.matricula}`;
    
    try {
      this.logger.log(`Validando abogado en Foro de Abogados: ${validarAbogadoDto.matricula}`);

      // 1. Verificar cache primero
      try {
        const cachedResult = await this.cacheManager.get<ValidacionResult>(cacheKey);
        if (cachedResult) {
          this.logger.log(`Resultado de abogado obtenido desde cache`);
          return cachedResult;
        }
      } catch (cacheError: any) {
        this.logger.warn(`Error accediendo cache: ${cacheError.message}`);
      }

      // 2. SIEMPRE consultar el Foro de Abogados real
      this.logger.log(`Consultando Foro de Abogados para matrícula: ${validarAbogadoDto.matricula}`);
      const resultado = await this.consultarForoAbogados(validarAbogadoDto.matricula);

      // 3. Guardar en cache por 24 horas si la consulta fue exitosa
      if (resultado && resultado.valido !== undefined) {
        try {
          await this.cacheManager.set(cacheKey, resultado, 86400000); // 24 horas
          this.logger.log(`Resultado guardado en cache para matrícula: ${validarAbogadoDto.matricula}`);
        } catch (cacheError: any) {
          this.logger.warn(`Error guardando en cache: ${cacheError.message}`);
        }
      }

      this.logger.log(`Abogado ${validarAbogadoDto.matricula} validado: ${resultado.valido}`);
      return resultado;

    } catch (error: any) {
      this.logger.error(`Error validando abogado: ${error.message}`);
      
      // Retornar estructura de error consistente
      return {
        valido: false,
        matricula: validarAbogadoDto.matricula,
        error: 'Error al consultar Foro de Abogados',
        message: error.message || 'Servicio no disponible temporalmente',
        fecha_validacion: new Date().toISOString(),
        fuente: 'FORO_ABOGADOS_ERROR'
      };
    }
  }

  // ================================================
  // SCRAPING CORRECTO DEL FORO DE ABOGADOS
  // ================================================

  private async consultarForoAbogados(matricula: string): Promise<ValidacionResult> {
    try {
      // La URL correcta que devuelve la tabla HTML directamente
      const url = 'https://app.funcionjudicial.gob.ec/ForoAbogados/Publico/frmConsultasGenerales.jsp';

      const headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
        'Accept-Language': 'es-ES,es;q=0.8,en-US;q=0.5,en;q=0.3',
        'Connection': 'keep-alive'
      };

      this.logger.log(`🔍 Obteniendo datos del Foro de Abogados...`);
      
      const response = await firstValueFrom(
        this.httpService.get(url, { 
          headers, 
          timeout: 20000,
          maxRedirects: 5 
        })
      );

      if (!response.data) {
        throw new Error('No se pudo obtener datos del Foro de Abogados');
      }

      // Parsear el HTML recibido
      const $ = cheerio.load(response.data);

      this.logger.log(`📋 Buscando matrícula: ${matricula} en la tabla de abogados...`);

      // El sitio devuelve una tabla con todos los abogados
      // Buscar la fila que contiene la matrícula específica
      let datosAbogado: {
        matricula: string;
        nombres: string;
        direccion_estudio: string;
        fecha_inscripcion: string;
        credencial: string;
        estado: string;
      } | undefined;
      
      // Debug: contar filas encontradas
      const totalFilas = $('tr').length;
      this.logger.log(`🔍 Total de filas encontradas: ${totalFilas}`);
      
      // Debug: mostrar una porción del HTML para verificar estructura
      this.logger.log(`📄 Muestra del HTML recibido: ${response.data.substring(0, 500)}`);
      
      // Buscar en todas las filas de la tabla
      $('tr').each((index, element) => {
        const fila = $(element);
        const celdas = fila.find('td');
        
        // Debug para las primeras 10 filas con contenido
        if (index < 10 && celdas.length > 0) {
          const primeracelda = $(celdas[0]).text().trim();
          this.logger.log(`Fila ${index}: ${celdas.length} celdas - Primera celda: "${primeracelda}"`);
          
          // Si parece una matrícula, mostrar más detalles
          if (primeracelda.includes('17-') || primeracelda.includes('MAT-')) {
            this.logger.log(`  🎯 Posible matrícula encontrada: "${primeracelda}"`);
            this.logger.log(`  Comparando con: "${matricula}"`);
            this.logger.log(`  Son iguales: ${primeracelda === matricula}`);
          }
        }
        
        // Si la fila tiene al menos 6 celdas (formato esperado según la imagen)
        if (celdas.length >= 6) {
          const matriculaEnTabla = $(celdas[0]).text().trim(); // PRIMERA columna es matrícula
          
          if (matriculaEnTabla === matricula) {
            // Extraer todos los datos de la fila según la estructura real:
            // [0] = MATRÍCULA, [1] = NOMBRES, [2] = DIRECCIÓN, [3] = INSCRIPCIÓN, [4] = CREDENCIAL, [5] = ESTADO
            const nombre = $(celdas[1]).text().trim();
            const direccion = $(celdas[2]).text().trim();
            const fechaInscripcion = $(celdas[3]).text().trim();
            const credencial = $(celdas[4]).text().trim();
            const estado = $(celdas[5]).text().trim();
            
            datosAbogado = {
              matricula: matriculaEnTabla,
              nombres: nombre,
              direccion_estudio: direccion,
              fecha_inscripcion: fechaInscripcion,
              credencial: credencial,
              estado: estado
            };
            
            this.logger.log(`✅ Abogado encontrado: ${nombre}`);
            return false; // Romper el loop
          }
        }
      });

      // Debug final: si no encontramos, intentar búsqueda más flexible
      if (!datosAbogado) {
        this.logger.log(`🔄 Búsqueda exacta falló, intentando búsqueda flexible...`);
        
        // Intentar encontrar la matrícula de forma más flexible
        $('td').each((index, element) => {
          const contenido = $(element).text().trim();
          if (contenido === matricula) {
            this.logger.log(`🎯 Matrícula encontrada en celda ${index}: "${contenido}"`);
            const fila = $(element).parent();
            const celdas = fila.find('td');
            
            if (celdas.length >= 6) {
              const nombre = $(celdas[1]).text().trim();
              const direccion = $(celdas[2]).text().trim();
              const fechaInscripcion = $(celdas[3]).text().trim();
              const credencial = $(celdas[4]).text().trim();
              const estado = $(celdas[5]).text().trim();
              
              datosAbogado = {
                matricula: contenido,
                nombres: nombre,
                direccion_estudio: direccion,
                fecha_inscripcion: fechaInscripcion,
                credencial: credencial,
                estado: estado
              };
              
              this.logger.log(`✅ Abogado encontrado (búsqueda flexible): ${nombre}`);
              return false;
            }
          }
        });
      }

      // Verificar si encontramos el abogado
      if (datosAbogado) {
        return {
          valido: true,
          matricula: datosAbogado.matricula,
          nombres: datosAbogado.nombres,
          cedula: null, // No disponible en esta tabla
          estado: datosAbogado.estado,
          fecha_inscripcion: datosAbogado.fecha_inscripcion,
          direccion_estudio: datosAbogado.direccion_estudio,
          credencial: datosAbogado.credencial,
          fecha_validacion: new Date().toISOString(),
          fuente: 'FORO_ABOGADOS'
        };
      }

      // Si no se encontró el abogado
      this.logger.log(`❌ Abogado no encontrado para matrícula: ${matricula}`);
      return {
        valido: false,
        matricula: matricula,
        motivo: 'Abogado no encontrado en el Foro de Abogados',
        sugerencia: 'Verifique que la matrícula esté correctamente escrita y que el abogado esté registrado',
        fecha_validacion: new Date().toISOString(),
        fuente: 'FORO_ABOGADOS'
      };

    } catch (error: any) {
      this.logger.error(`💥 Error en consulta Foro Abogados: ${error.message}`);
      
      if (error.code === 'ECONNREFUSED' || error.code === 'ENOTFOUND') {
        throw new HttpException(
          'No se puede conectar al sitio del Foro de Abogados. Verifique su conexión a internet.',
          HttpStatus.SERVICE_UNAVAILABLE
        );
      }
      
      if (error.response?.status === 503) {
        throw new HttpException(
          'El sitio del Foro de Abogados está temporalmente no disponible.',
          HttpStatus.SERVICE_UNAVAILABLE
        );
      }

      throw new HttpException(
        `Error al consultar Foro de Abogados: ${error.message}`,
        HttpStatus.BAD_GATEWAY
      );
    }
  }

  // ================================================
  // HEALTH CHECK
  // ================================================

  async healthCheck() {
    return {
      status: 'ok',
      timestamp: new Date().toISOString(),
      service: 'validacion-foro-abogados',
      version: '1.0.0',
      description: 'Validación de abogados mediante consulta real al Foro de Abogados del Ecuador',
      endpoints: {
        validar_abogado: 'POST /validaciones/abogado'
      },
      fuente_datos: 'https://app.funcionjudicial.gob.ec/ForoAbogados/',
      nota: 'Consulta directa a tabla HTML del sitio oficial'
    };
  }
}