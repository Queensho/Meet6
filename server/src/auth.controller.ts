import { Body, Controller, Headers, Post } from '@nestjs/common';

import {
  LoginPasswordDto,
  RegisterPasswordDto,
  RequestOtpDto,
  VerifyOtpDto,
} from './auth.dto';
import { AuthService } from './auth.service';

@Controller('auth')
export class AuthController {
  constructor(private readonly auth: AuthService) {}

  @Post('register')
  register(@Body() body: RegisterPasswordDto) {
    return this.auth.registerWithPassword(body.phone, body.password);
  }

  @Post('login')
  login(@Body() body: LoginPasswordDto) {
    return this.auth.loginWithPassword(body.phone, body.password);
  }

  @Post('request-code')
  requestCode(@Body() body: RequestOtpDto) {
    return this.auth.requestCode(body.phone);
  }

  @Post('verify-code')
  verifyCode(@Body() body: VerifyOtpDto) {
    return this.auth.verifyCode(body.phone, body.code);
  }

  @Post('logout')
  logout(@Headers('authorization') authorization?: string) {
    return this.auth.logout(authorization);
  }
}
