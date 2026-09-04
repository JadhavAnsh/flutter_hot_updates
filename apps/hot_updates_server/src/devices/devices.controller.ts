import { Body, Controller, Param, Post, UseGuards } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { DevicesService } from './devices.service';
import { RegisterDeviceDto } from './dto/register-device.dto';
import { RateLimitGuard } from '../common/rate-limit.guard';

@ApiTags('devices')
@Controller('projects/:projectId')
export class DevicesController {
  constructor(private readonly devices: DevicesService) {}

  // Public, unauthenticated, rate-limited. Called by the Flutter client to
  // register itself and report its currently active patch.
  @Post('devices')
  @UseGuards(RateLimitGuard)
  register(
    @Param('projectId') projectId: string,
    @Body() dto: RegisterDeviceDto,
  ) {
    return this.devices.register(projectId, dto);
  }
}
