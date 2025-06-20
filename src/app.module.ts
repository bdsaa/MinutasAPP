// src/app.module.ts
import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';

import { AppController } from './app.controller';
import { AppService } from './app.service';

// Importar solo el módulo de validación
import { ValidacionModule } from './services/validacion/validacion.module';

@Module({
  imports: [
    // Configuración global básica
    ConfigModule.forRoot({ 
      isGlobal: true,
      envFilePath: '.env',
    }),
    
    // Solo el módulo de validación por ahora
    ValidacionModule,
  ],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule {}