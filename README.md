quik_pipe
=========

API для получения данных из Quik через Windows named pipe


Примеры использования см в QuikCommandPipeAdapter

		try(QuikCommandPipeAdapter adapter = new QuikCommandPipeAdapter()) {
			long started = System.currentTimeMillis();
			// соединение с сервером Quik
			System.out.println(adapter.isConnectedToServer(false));
			// торговый день
			System.out.println(adapter.getTradeDate(false));
			// стакан по инструменту
			System.out.println(adapter.executeRequest("staSPBFUT:Si-12.14", false));
			// текущее время сервера
			System.out.println(adapter.getServerCurrentTime(false).replaceAll(":", ""));
			// Гарантийное обеспечение
			System.out.println("ГО : " + adapter.getContractPrice("SPBFUT", "Si-12.14", false));
			// Последние Н (50) свечек
			System.out.println(adapter.getLastCandlesOf("SPBFUT", "Si-12.14", Interval.HOUR, 50, false));

