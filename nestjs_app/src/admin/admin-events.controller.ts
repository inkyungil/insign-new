import { Controller, Get, Post, Render, Req, Res, Body, Param } from '@nestjs/common';
import { Response } from 'express';
import { EventsService } from '../events/events.service';
import { CreateEventDto } from '../events/dto/create-event.dto';
import { UpdateEventDto } from '../events/dto/update-event.dto';

@Controller('adm/events')
export class AdminEventsController {
  constructor(private readonly eventsService: EventsService) {}

  // GET /adm/events - 이벤트 목록
  @Get()
  @Render('admin/events/index')
  async listEvents(@Req() req: any) {
    const events = await this.eventsService.findAll();
    return {
      admin: req.user,
      events,
      message: null,
    };
  }

  // GET /adm/events/new - 이벤트 등록 폼
  @Get('new')
  @Render('admin/events/new')
  async newEventForm(@Req() req: any) {
    return {
      admin: req.user,
      event: null,
      errors: null,
    };
  }

  // POST /adm/events - 이벤트 생성
  @Post()
  async createEvent(@Body() createEventDto: CreateEventDto, @Res() res: Response) {
    try {
      await this.eventsService.create(createEventDto);
      res.redirect('/adm/events?message=' + encodeURIComponent('이벤트가 등록되었습니다.'));
    } catch (error: any) {
      res.redirect('/adm/events/new?error=' + encodeURIComponent(error?.message || '오류가 발생했습니다.'));
    }
  }

  // GET /adm/events/:id/edit - 이벤트 수정 폼
  @Get(':id/edit')
  @Render('admin/events/edit')
  async editEventForm(@Param('id') id: string, @Req() req: any) {
    const event = await this.eventsService.findOne(+id);
    return {
      admin: req.user,
      event,
      errors: null,
    };
  }

  // POST /adm/events/:id - 이벤트 수정
  @Post(':id')
  async updateEvent(
    @Param('id') id: string,
    @Body() updateEventDto: UpdateEventDto,
    @Res() res: Response,
  ) {
    try {
      await this.eventsService.update(+id, updateEventDto);
      res.redirect('/adm/events?message=' + encodeURIComponent('이벤트가 수정되었습니다.'));
    } catch (error: any) {
      res.redirect(`/adm/events/${id}/edit?error=` + encodeURIComponent(error?.message || '오류가 발생했습니다.'));
    }
  }

  // POST /adm/events/:id/delete - 이벤트 삭제
  @Post(':id/delete')
  async deleteEvent(@Param('id') id: string, @Res() res: Response) {
    try {
      await this.eventsService.remove(+id);
      res.redirect('/adm/events?message=' + encodeURIComponent('이벤트가 삭제되었습니다.'));
    } catch (error: any) {
      res.redirect('/adm/events?error=' + encodeURIComponent(error?.message || '오류가 발생했습니다.'));
    }
  }
}
