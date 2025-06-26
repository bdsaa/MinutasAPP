import {
  Controller,
  Post,
  Body,
  HttpCode,
  HttpStatus,
  Get
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse, ApiBody } from '@nestjs/swagger';
import { ValidarAbogadoDto } from './dto/validar-abogado.dto';
import { ValidacionService } from './validacion.service';

@Controller('validaciones')
@ApiTags('validaciones')
export class ValidacionController {
  constructor(private readonly validacionService: ValidacionService) {}

  @Post('abogado')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'Validar abogado en Foro de Abogados',
    description: 'Valida si un abogado está registrado en el Foro de Abogados del Ecuador mediante Puppeteer'
  })
  @ApiBody({ type: ValidarAbogadoDto })
  @ApiResponse({ status: 200, description: 'Resultado de la validación' })
  async validarAbogado(@Body() dto: ValidarAbogadoDto) {
    return this.validacionService.validarAbogadoConPaginacion(dto.matricula);
  }

  @Get('health')
  @HttpCode(HttpStatus.OK)
  async healthCheck() {
    return {
      status: 'ok',
      timestamp: new Date().toISOString(),
      service: 'validacion-foro-abogados-puppeteer',
      version: '3.3.0'
    };
  }
}