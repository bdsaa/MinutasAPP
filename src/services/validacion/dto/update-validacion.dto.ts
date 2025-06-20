import { PartialType } from '@nestjs/swagger';
import { CreateValidacionDto } from './create-validacion.dto';

export class UpdateValidacionDto extends PartialType(CreateValidacionDto) {}
