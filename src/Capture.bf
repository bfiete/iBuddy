#pragma warning disable 168
using System;
using System.IO;
using Beefy.geom;
using System.Collections;
using System.Threading;
using System.Diagnostics;

namespace iBuddy
{
	class Capture
	{
		[CRepr]
		struct BitmapInfoHeader
		{
			public int32 biSize;
			public int32 biWidth;
			public int32 biHeight;
			public int16 biPlanes;
			public int16 biBitCount;
			public int32 biCompression;
			public int32 biSizeImage;
			public int32 biXPelsPerMeter;
			public int32 biYPelsPerMeter;
			public int32 biClrUsed;
			public int32 biClrImportant;
		}

		[CRepr]
		struct BitmapInfo
		{
			  public BitmapInfoHeader bmiHeader;
			  public uint32[1] bmiColors;
		}

		struct IntRect
		{
			public int32 mX, mY, mWidth, mHeight;
		}

		[CLink, CallingConvention(.Stdcall)]
		public static extern Windows.Handle GetDC(Windows.HWnd hwnd);

		[Import("gdi32.lib"), CLink, CallingConvention(.Stdcall)]
		public static extern Windows.Handle CreateCompatibleDC(Windows.Handle hwnd);

		[CLink, CallingConvention(.Stdcall)]
		public static extern Windows.Handle CreateCompatibleBitmap(Windows.Handle hdc, int width, int height);

		[CLink, CallingConvention(.Stdcall)]
		public static extern void SelectObject(Windows.Handle tgt, Windows.Handle obj);

		[CLink, CallingConvention(.Stdcall)]
		public static extern Windows.IntBool GetClientRect(Windows.HWnd hwnd, out IntRect obj);

		[CLink, CallingConvention(.Stdcall)]
		public static extern Windows.IntBool GetWindowRect(Windows.HWnd hwnd, out IntRect obj);

		[CLink, CallingConvention(.Stdcall)]
		public static extern Windows.IntBool AdjustWindowRect(ref IntRect rect, uint32 style, bool bMenu);

		[CLink, CallingConvention(.Stdcall)]
		public static extern void BitBlt(Windows.Handle dest, int x, int y, int width, int height, Windows.Handle obj, int srcX, int srcY, int kind);

		[CLink, CallingConvention(.Stdcall)]
		public static extern Windows.Handle CreateDIBSection(Windows.Handle hdc, BitmapInfo* pbmi, uint32 usage, out void* ppvBits, Windows.Handle hSection, uint32 offset);

		[CLink, CallingConvention(.Stdcall)]
		public static extern Span<uint8> Res_JPEGCompress(uint32* bits, int width, int height, int quality);

		[CLink, CallingConvention(.Stdcall)]
		public static extern void Capture_GetFrame(uint8* bits, int x, int y, int width, int height);

		[CLink, CallingConvention(.Stdcall)]
		public static extern Span<uint8> Capture_GetFrameJPEG(int x, int y, int width, int height, int quality);

		const int32 SRCCOPY = 0x00CC0020;
		const int32 DIB_RGB_COLORS = 0;

		public List<uint8> mImage = new .() ~ delete _;
		public Monitor mMonitor = new .() ~ delete _;
		public Thread mThread ~ delete _;
		public bool mWantImage;
		public volatile bool mDone;

		public this()
		{
			mThread = new Thread(new => Run);
			mThread.Start(false);
		}

		public ~this()
		{
			mDone = true;
			mThread.Join();
		}

		public void Run()
		{
			Thread.CurrentThread.SetName("Capture");

			Stopwatch sw = scope .();
			sw.Start();

			int frameTime = 200;

			bool testing = false;
			if (testing)
			{
				mWantImage = true;
				frameTime = 0;
			}

			int count = 0;

			while (!mDone)
			{
				Thread.Sleep(8);

				if (sw.ElapsedMilliseconds < frameTime)
					continue;
				sw.Restart();

				using (mMonitor.Enter())
				{
					if (!mImage.IsEmpty)
						continue;
				}

				if (!mWantImage)
					continue;

				var hwnd = Windows.FindWindowA(null, "iRacing.com Simulator");
				if (hwnd == default)
					hwnd = Windows.FindWindowA(null, "iBuddy - Beef IDE [d2]");

				if (hwnd == default)
					return;

				Stopwatch sw2 = scope .();
				sw2.Start();

				GetWindowRect(hwnd, var windowRect);
				GetClientRect(hwnd, var clientRect);

				int width = clientRect.mWidth;
				int height = clientRect.mHeight;

				AdjustWindowRect(ref clientRect, (.)Windows.GetWindowLong(hwnd, -16), false);

				uint8* bits = new uint8[width * height * 4]*;
				defer delete bits;

				Span<uint8> data = default;
				data = Capture_GetFrameJPEG(windowRect.mX - clientRect.mX, windowRect.mY - clientRect.mY, width, height, 25);

				using (mMonitor.Enter())
				{
					if (!testing)
						mImage.Insert(0, data);
				}

				sw2.Stop();
				//Debug.WriteLine($"Capture: {Thread.CurrentThread.Id} {sw2.ElapsedMilliseconds}");

				count++;
			}
		}

		public void Capture()
		{
			//var hwnd = Windows.FindWindowA(null, "iBuddy - Beef IDE [d2]");8
			var hwnd = Windows.FindWindowA(null, "iRacing.com Simulator");

			if (hwnd == default)
				return;

			GetWindowRect(hwnd, var windowRect);
			GetClientRect(hwnd, var clientRect);

			int width = clientRect.mWidth;
			int height = clientRect.mHeight;

			AdjustWindowRect(ref clientRect, (.)Windows.GetWindowLong(hwnd, -16), false);

			uint8* bits = new uint8[width * height * 4]*;
			defer delete bits;
			Capture_GetFrame(bits, windowRect.mX - clientRect.mX, windowRect.mY - clientRect.mY, width, height);

			var data = Res_JPEGCompress((.)bits, width, height, 25);
			File.WriteAll(@"c:\temp\test.jpg", data);


			//var hwnd = Windows.FindWindowA(null, "iRacing.com Simulator");
			/*if (hwnd == default)
				return;
			var origDC = GetDC(hwnd);
			var compatDC = CreateCompatibleDC(origDC);

			BitmapInfo bitmapInfo = default;
			bitmapInfo.bmiHeader.biSize = sizeof(BitmapInfoHeader);
			bitmapInfo.bmiHeader.biWidth = (.)width;
			bitmapInfo.bmiHeader.biHeight = (.)height;
			bitmapInfo.bmiHeader.biPlanes = 1;
			bitmapInfo.bmiHeader.biBitCount = 32;

			var bitmap = CreateDIBSection(compatDC, &bitmapInfo, DIB_RGB_COLORS, var bits, default, 0);

			//var bitmap = CreateCompatibleBitmap(origDC, width, height);

			SelectObject(compatDC, bitmap);
			BitBlt(compatDC, 0, 0, width, height, origDC, 0, 0, SRCCOPY);

			var data = Res_JPEGCompress((.)bits, width, height, 25);
			File.WriteAll(@"c:\temp\test.jpg", data);*/
		}
	}
}
