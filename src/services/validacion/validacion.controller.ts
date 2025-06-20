// src/services/validacion/validacion.controller.ts
import { 
  Controller, 
  Post, 
  Body, 
  HttpCode, 
  HttpStatus, 
  UseGuards,
  Get 
} from '@nestjs/common';
import { 
  ApiTags, 
  ApiOperation, 
  ApiResponse,
  ApiBody 
} from '@nestjs/swagger';
import { ThrottlerGuard } from '@nestjs/throttler';

import { ValidacionService, ValidacionResult } from './validacion.service';
import { ValidarAbogadoDto } from './dto/validar-abogado.dto';

@Controller('validaciones')
@ApiTags('validaciones')
@UseGuards(ThrottlerGuard)
export class ValidacionController {
  constructor(
    private readonly validacionService: ValidacionService,
  ) {}

  // ================================================
  // ENDPOINT: VALIDAR ABOGADO POR MATRÍCULA
  // ================================================
  
  @Post('abogado')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ 
    summary: 'Validar abogado en Foro de Abogados',
    description: 'Valida que el abogado esté registrado y activo en el Foro de Abogados del Ecuador por matrícula'
  })
  @ApiBody({
    type: ValidarAbogadoDto,
    description: 'Datos de la matrícula del abogado a validar',
    examples: {
      ejemplo1: {
        summary: 'Matrícula válida',
        value: {
          matricula: '17-2009-7'
        }
      },
      ejemplo2: {
        summary: 'Otra matrícula válida',
        value: {
          matricula: 'MAT-2020-1234'
        }
      }
    }
  })
  @ApiResponse({ 
    status: 200, 
    description: 'Abogado validado exitosamente',
    schema: {
      oneOf: [
        {
          title: 'Abogado válido',
          example: {
            valido: true,
            matricula: '17-2009-7',
            nombres: 'CAJO SAMANIEGO IVAN URGENCIO',
            cedula: null,
            estado: 'Validado',
            fecha_inscripcion: 'Marzo, 30 de 2010',
            direccion_estudio: 'CDELA. DEL EJERCITO CALLE P Y Q CASA 756',
            credencial: 'Si',
            fecha_validacion: '2025-06-20T19:45:00Z',
            fuente: 'FORO_ABOGADOS'
          }
        },
        {
          title: 'Abogado no encontrado',
          example: {
            valido: false,
            matricula: 'MAT-INEXISTENTE',
            motivo: 'Abogado no encontrado en el Foro de Abogados',
            sugerencia: 'Verifique que la matrícula esté correctamente escrita y que el abogado esté registrado',
            fecha_validacion: '2025-06-20T19:45:00Z',
            fuente: 'FORO_ABOGADOS'
          }
        }
      ]
    }
  })
  @ApiResponse({ 
    status: 400, 
    description: 'Matrícula inválida o datos incorrectos',
    schema: {
      example: {
        statusCode: 400,
        message: ['matricula should not be empty', 'matricula must be a string'],
        error: 'Bad Request'
      }
    }
  })
  @ApiResponse({ 
    status: 429, 
    description: 'Demasiadas solicitudes. Rate limit excedido.',
    schema: {
      example: {
        statusCode: 429,
        message: 'ThrottlerException: Too Many Requests',
        error: 'Too Many Requests'
      }
    }
  })
  @ApiResponse({ 
    status: 503, 
    description: 'Servicio Foro de Abogados no disponible',
    schema: {
      example: {
        valido: false,
        matricula: '17-2009-7',
        error: 'Error al consultar Foro de Abogados',
        message: 'Servicio no disponible temporalmente',
        fecha_validacion: '2025-06-20T19:45:00Z',
        fuente: 'FORO_ABOGADOS_ERROR'
      }
    }
  })
  async validarAbogado(@Body() validarAbogadoDto: ValidarAbogadoDto): Promise<ValidacionResult> {
    return this.validacionService.validarAbogado(validarAbogadoDto);
  }

  // ================================================
  // ENDPOINT: HEALTH CHECK
  // ================================================

  @Get('health')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ 
    summary: 'Health check del servicio de validaciones',
    description: 'Verifica que el servicio de validaciones esté funcionando correctamente'
  })
  @ApiResponse({ 
    status: 200, 
    description: 'Servicio funcionando correctamente',
    schema: {
      example: {
        status: 'ok',
        timestamp: '2025-06-20T19:45:00Z',
        service: 'validacion-foro-abogados',
        version: '1.0.0',
        description: 'Validación de abogados mediante consulta real al Foro de Abogados del Ecuador',
        endpoints: {
          validar_abogado: 'POST /validaciones/abogado'
        },
        fuente_datos: 'https://app.funcionjudicial.gob.ec/ForoAbogados/',
        nota: 'Consulta directa a tabla HTML del sitio oficial'
      }
    }
  })
  async healthCheck() {
    return this.validacionService.healthCheck();
  }
}