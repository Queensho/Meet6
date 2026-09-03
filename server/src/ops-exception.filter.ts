import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpException,
  HttpStatus,
} from '@nestjs/common';

type OpsRequest = {
  method?: string;
  originalUrl?: string;
  url?: string;
  opsRequestId?: string;
};

type OpsResponse = {
  status(code: number): OpsResponse;
  json(body: unknown): void;
};

function exceptionMessage(exception: unknown, responseBody: unknown) {
  if (exception instanceof Error && exception.message) return exception.message;
  if (typeof responseBody === 'string') return responseBody;
  if (responseBody && typeof responseBody === 'object' && 'message' in responseBody) {
    const message = (responseBody as { message?: unknown }).message;
    if (Array.isArray(message)) return message.join('; ');
    if (typeof message === 'string') return message;
  }
  return 'Unhandled server error';
}

@Catch()
export class OpsExceptionFilter implements ExceptionFilter {
  catch(exception: unknown, host: ArgumentsHost) {
    const http = host.switchToHttp();
    const request = http.getRequest<OpsRequest>();
    const response = http.getResponse<OpsResponse>();

    const isHttp = exception instanceof HttpException;
    const status = isHttp ? exception.getStatus() : HttpStatus.INTERNAL_SERVER_ERROR;
    const rawBody = isHttp ? exception.getResponse() : null;
    const message = exceptionMessage(exception, rawBody);

    if (status >= 500) {
      const event = {
        timestamp: new Date().toISOString(),
        level: 'error',
        event: 'http_exception',
        service: 'meet6-api',
        status,
        method: request.method ?? null,
        path: request.originalUrl ?? request.url ?? null,
        requestId: request.opsRequestId ?? null,
        message,
        stack: exception instanceof Error ? exception.stack ?? null : null,
      };
      // PM2 sends stderr to /var/log/meet6/api-error.log. The production
      // error-watch timer tracks these structured events and can alert a webhook.
      // eslint-disable-next-line no-console
      console.error(JSON.stringify(event));
    }

    if (isHttp) {
      if (typeof rawBody === 'string') {
        response.status(status).json({ statusCode: status, message: rawBody });
      } else {
        response.status(status).json(rawBody);
      }
      return;
    }

    response.status(status).json({
      statusCode: status,
      message: 'Internal server error',
    });
  }
}
