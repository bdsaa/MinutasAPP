import { IsString, IsNotEmpty, Matches, Length, IsOptional } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class ValidarAbogadoDto {
    @ApiProperty({
        description: 'Número de matricula del abogado',
        example: '17-2009-7'
    })
    @IsString()
    @IsNotEmpty()
    matricula: string;
}