using System;
using System.IO;
using System.Diagnostics;
using System.Threading;
using System.Collections;

namespace iReplay
{
	class Program
	{
		const String cDataValidEventName = "Local\\IRSDKDataValidEvent";
		const String cMemMapFilaname = "Local\\IRSDKMemMapFileName";

		struct KeyEventRecord
		{
			public bool bKeyDown;
			public uint16 wRepeatCount;
			public uint16 wVirtualKeyCode;
			public uint16 wVirtualScanCode;
			public char16 UnicodeChar;
			public uint32 dwControlKeyState;
		}

		struct INPUT_RECORD
		{
			public uint32 mEventType;
			public uint8[64] mData;
		}

		[CLink, LinkName(.C)]
		public static extern Windows.IntBool ReadConsoleInputW(Windows.Handle hConsoleInput, INPUT_RECORD* lpBuffer, uint32 nLength, out uint32 lpNumberOfEventsRead);

		[CLink, LinkName(.C)]
		public static extern Windows.IntBool SetConsoleMode(Windows.Handle hConsoleInput, uint32 flags);

		[CLink, LinkName(.C)]
		public static extern Windows.IntBool GetNumberOfConsoleInputEvents(Windows.Handle hConsoleInput, out int32 numEvents);

		public static int Main(String[] args)
		{
			OpenFileDialog ofd = scope .();

			String fn = null;
			if (args.Count > 0)
			{
				fn = args[0];
			}
			else
			{
				ofd.DefaultExt = ".dat";
				if (ofd.ShowDialog() case .Err)
					return 0;
				fn = ofd.FileNames[0];
			}

			IRApp irApp = scope .();
			irApp.Init();
			irApp.Show(fn);
			irApp.Run();
			irApp.Shutdown();

			return 0;

			/*List<char8> keys = scope .();
			Monitor monitor = scope .();*/

			/*Thread keyThread = scope .(new () =>
				{
					while (true)
					{
						if (Console.Read() case .Ok(let c))
						{
							using (monitor.Enter())
							{
								keys.Add(c);
							}
						}
					}
				});
			keyThread.Start();*/

			FileStream stream = scope .();
			stream.Open(args[0], .Read);

			var sharedMemorySize = stream.Read<int32>().Value;
			//uint8* data = new uint8[sharedMemorySize]*;
			//defer delete data;

			var fileMapping = Windows.CreateFileMappingA(Windows.Handle.InvalidHandle, null, Windows.PAGE_READWRITE, 0, (.)sharedMemorySize, cMemMapFilaname);
			var event = Windows.CreateEventA(null, true, false, cDataValidEventName);
			uint8* data = (.)Windows.MapViewOfFile(fileMapping, Windows.FILE_MAP_WRITE, 0, 0, 0);

			var inStdHandle = Windows.GetStdHandle((.)Console.[Friend]STD_INPUT_HANDLE);

			//SetConsoleMode(inStdHandle, 0x0008 | 0x0010);
			SetConsoleMode(inStdHandle, 0);

			double dataTick = 0;
			uint32 lastCheckTick = Platform.BfpSystem_TickCount();
			uint32 lastWriteTick = lastCheckTick;
			
			int32 curDataTick = -1;
			int32 nextDataTick = -1;
			float speed = 1.0f;
			List<uint8> imageData = scope .();

			while (true)
			{
				if (nextDataTick == -1)
				{
					nextDataTick = stream.Read<int32>();

					if (nextDataTick == -1)
					{
						imageData.Clear();

						int32 imageSize = stream.Read<int32>();
						imageData.Count = imageSize;

						stream.TryRead((Span<uint8>)imageData).IgnoreError();
					}
				}

				uint32 curCheckTick = Platform.BfpSystem_TickCount();
				int32 elapsed = (.)(curCheckTick - lastCheckTick);
				lastCheckTick = curCheckTick;

				dataTick += elapsed * speed;
				if (dataTick >= nextDataTick)
				{
					//Windows.ResetEvent(event);

					curDataTick = nextDataTick;

					uint8* ptr = data;

					DecodeLoop:
					while (true)
					{
						//int fpos = fs.Position;

						Debug.Assert(ptr - data < sharedMemorySize);

						uint8 c = stream.Read<uint8>().Value;
						int delta = -1;

						switch (c)
						{
						case 0xA4:
							break DecodeLoop;
						case 0xA3:
							delta = stream.Read<int32>().Value;
						case 0xA2:
							delta = stream.Read<uint16>().Value;
						case 0xA1:
							delta = stream.Read<uint8>().Value;
						}

						if (delta != -1)
						{
							ptr += delta;
							c = stream.Read<uint8>();
						}

						if (c == 0xA0)
							c = stream.Read<uint8>();

						/*if ((c >= 0xA0) && (c <= 0xA4))
						{
							c = fs.Read<uint8>();
						}*/
						*(ptr++) = c;
					}

					Windows.SetEvent(event);
					

					/*using (monitor.Enter())
					{
						while (!keys.IsEmpty)
						{
							var c = keys.PopFront();
							if ((c == '+') || (c == '='))
								speed *= 1.5f;
							if (c == '-')
								speed /= 1.5f;
							if (c == '0')
								speed = 1.0f;
						}
					}*/

					nextDataTick = -1;
				}
				else
					Thread.Sleep(1);

				if (curCheckTick - lastWriteTick >= 50)
				{
					int sec = curDataTick / 1000;
					Console.Write("\r");
					Console.Write($"Tick: {sec / 60}:{sec % 60:00} Speed: {speed:0.0}");
					Console.Out.Flush();

					lastWriteTick = curCheckTick;

					while (true)
					{
						INPUT_RECORD inputRecord = default;

						GetNumberOfConsoleInputEvents(inStdHandle, var numEvents);
						if (numEvents <= 0)
							break;
						ReadConsoleInputW(inStdHandle, &inputRecord, 1, var readRecords);
						if (readRecords > 0)
						{
							if (inputRecord.mEventType == 1)
							{
								KeyEventRecord* keyEvt = (.)&inputRecord.mData;

								//Debug.WriteLine($"{keyEvt.UnicodeChar} {keyEvt.wRepeatCount} {keyEvt.bKeyDown} {keyEvt.dwControlKeyState}");
								if (keyEvt.dwControlKeyState == 1)
								{
									switch (keyEvt.UnicodeChar)
									{
									case '+',
										  '=':
										speed *= 1.5f;
									case '-':
										speed /= 1.5f;
									case '0':
										speed = 1;
									case '1':
										dataTick += 5000.0;
									case '2':
										dataTick += 15000.0;
									case '3':
										dataTick += 60000.0;
									case 'p':
										speed = 0;
									}
								}
							}
						}
					}
				}
			}

#unwarn
			return 0;
		}
	}
}