import { Controller, Get } from '@nestjs/common';
import { EventsService } from './events.service';
import { Event } from './event.entity';

@Controller('api/events')
export class EventsController {
  constructor(private readonly eventsService: EventsService) {}

  // GET /api/events - 전체 이벤트 목록
  @Get()
  async getAllEvents(): Promise<Event[]> {
    return this.eventsService.findAll();
  }
}
