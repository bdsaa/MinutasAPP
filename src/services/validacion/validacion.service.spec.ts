import { Test, TestingModule } from '@nestjs/testing';
import { ValidacionService } from './validacion.service';

describe('ValidacionService', () => {
  let service: ValidacionService;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [ValidacionService],
    }).compile();

    service = module.get<ValidacionService>(ValidacionService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });
});
