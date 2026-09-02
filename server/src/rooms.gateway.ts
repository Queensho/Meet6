import {
  ConnectedSocket,
  MessageBody,
  SubscribeMessage,
  WebSocketGateway,
  WebSocketServer,
} from '@nestjs/websockets';
import type { Server, Socket } from 'socket.io';

@WebSocketGateway({
  namespace: '/rooms',
  transports: ['websocket', 'polling'],
  cors: {
    origin: ['https://queensho.github.io'],
    credentials: true,
  },
})
export class RoomsGateway {
  @WebSocketServer()
  server!: Server;

  handleConnection(client: Socket) {
    client.emit('server:ready', {
      ok: true,
      socketId: client.id,
      timestamp: new Date().toISOString(),
    });
  }

  @SubscribeMessage('ping')
  ping(@ConnectedSocket() client: Socket, @MessageBody() payload: unknown) {
    return {
      event: 'pong',
      data: {
        socketId: client.id,
        payload: payload ?? null,
        timestamp: new Date().toISOString(),
      },
    };
  }
}
