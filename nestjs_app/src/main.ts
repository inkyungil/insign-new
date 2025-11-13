import { NestFactory } from "@nestjs/core";
import { ConfigService } from "@nestjs/config";
import { NestExpressApplication } from "@nestjs/platform-express";
import * as session from "express-session";
import * as cookieParser from "cookie-parser";
import * as passport from "passport";
import { json, urlencoded } from "express";
import { join } from "path";
import { SwaggerModule, DocumentBuilder } from "@nestjs/swagger";
import { AppModule } from "./app.module";

async function bootstrap() {
  const app = await NestFactory.create<NestExpressApplication>(AppModule);
  const configService = app.get(ConfigService);

  const defaultOrigins = [
    "https://in-sign.shop",
    "https://dev.in-sign.shop",
    "http://localhost:8081",
    "http://localhost:19006",
  ];
  const configuredOrigins = configService
    .get<string>("CORS_ORIGINS")
    ?.split(",")
    .map((origin) => origin.trim())
    .filter(Boolean);
  const allowedOrigins = Array.from(
    new Set([...(configuredOrigins ?? []), ...defaultOrigins]),
  );

  app.enableCors({
    origin: (origin, callback) => {
      if (!origin || allowedOrigins.includes(origin)) {
        return callback(null, true);
      }
      return callback(new Error(`Origin ${origin} is not allowed by CORS`));
    },
    methods: ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    allowedHeaders: [
      "Content-Type",
      "Authorization",
      "X-Requested-With",
      "Accept",
    ],
    credentials: true,
  });

  app.setBaseViewsDir(join(__dirname, "..", "views"));
  app.setViewEngine("ejs");
  app.useStaticAssets(join(__dirname, "..", "public"), {
    prefix: "/static/",
  });

  const bodyLimit = configService.get<string>("REQUEST_BODY_LIMIT", "5mb");
  app.use(json({ limit: bodyLimit }));
  app.use(urlencoded({ extended: true, limit: bodyLimit }));

  const sessionSecret = configService.get<string>(
    "SESSION_SECRET",
    "change-me",
  );
  const sessionMaxAge = Number(
    configService.get<string>("SESSION_MAX_AGE", (1000 * 60 * 60).toString()),
  );

  app.use(cookieParser(sessionSecret));
  app.use(
    session({
      secret: sessionSecret,
      resave: false,
      saveUninitialized: false,
      cookie: {
        httpOnly: true,
        secure: false,
        sameSite: "lax",
        maxAge: Number.isNaN(sessionMaxAge) ? 1000 * 60 * 60 : sessionMaxAge,
      },
    }),
  );

  app.use(passport.initialize());
  app.use(passport.session());

  const swaggerConfig = new DocumentBuilder()
    .setTitle("Insign API")
    .setDescription("REST API and Admin backend powered by NestJS")
    .setVersion("0.0.1")
    .build();

  const document = SwaggerModule.createDocument(app, swaggerConfig);
  SwaggerModule.setup("docs", app, document, {
    jsonDocumentUrl: "docs/json",
    swaggerOptions: {
      persistAuthorization: true,
    },
  });

  const port = Number(configService.get<string>("PORT", "8081"));
  await app.listen(Number.isNaN(port) ? 8081 : port);
}

bootstrap();
