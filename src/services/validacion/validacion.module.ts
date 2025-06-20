// src/services/validacion/validacion.module.ts
import { Module } from '@nestjs/common';
import { HttpModule } from '@nestjs/axios';
import { ConfigModule } from '@nestjs/config';
import { CacheModule } from '@nestjs/cache-manager';
import { ThrottlerModule } from '@nestjs/throttler';

import { ValidacionController } from './validacion.controller';
import { ValidacionService } from './validacion.service';

@Module({
  imports: [
    // HttpModule con configuración específica
    HttpModule.registerAsync({
      useFactory: () => ({
        timeout: 15000,
        maxRedirects: 3,
        headers: {
          'User-Agent': 'LegalDocsSystem/1.0 (compatible; MSIE 9.0)',
        },
      }),
    }),
    
    // ConfigModule
    ConfigModule.forFeature(() => ({
      USER_AGENT: process.env.USER_AGENT || 'LegalDocsSystem/1.0',
      NODE_ENV: process.env.NODE_ENV || 'development',
    })),
    
    // CacheModule con configuración específica
    CacheModule.register({
      ttl: 86400000, // 24 horas en millisegundos
      max: 1000,
    }),
    
    // ThrottlerModule local
    ThrottlerModule.forRoot([{
      ttl: 60000,
      limit: 5, // 5 requests por minuto para scraping
    }]),
  ],
  controllers: [ValidacionController],
  providers: [ValidacionService],
  exports: [ValidacionService],
})
export class ValidacionModule {}