#pragma warning disable 168

using Beefy;
using iRacing;
using Beefy.widgets;
using Beefy.gfx;
using Beefy.theme.dark;
using Beefy.theme;
using System;
using Beefy.input;
using System.Diagnostics;
using System.Collections;
using System.IO;
using System.Threading;

namespace iBuddy
{
	class IBApp : BFApp
	{
		public enum LapInputState
		{
			Disabled,
			Record,
			Compare
		}

		public Monitor mMonitor = new .() ~ delete _;
		public IRSdk mIRSdk ~ delete _;

		public InputDevice mWheelbaseInputDevice ~ delete _;
		public InputDevice mWheelInputDevice ~ delete _;
		public InputDevice mPedalsInputDevice ~ delete _;
		public InputManager mInputManager ~ delete _;
		public SimInputManager mSimInputManager ~ delete _;
		
		public WidgetWindow mBoardWindow;
		public Board mBoard;

		public WidgetWindow mConfigWindow;
		public ConfigWidget mConfigWidget;

		public WidgetWindow mLapInputWindow;
		public LapInputWidget mLapInputWidget;
		
		public Font mTinyMonoFont ~ delete _;
		public Font mSmFont ~ delete _;
		public Font mSmMonoFont ~ delete _;
		public Font mMedFont ~ delete _;
		public Font mMedMonoFont ~ delete _;
		public Font mLgMonoFont ~ delete _;
		public Image mMapCarImage ~ delete _;
		public Image mMapPointerImage ~ delete _;
		public Image mChevronImage ~ delete _;
		public LapInputState mLapInputState;
		public Capture mCapture = new .() ~ delete _;

		[CallingConvention(.Stdcall), CLink]
		public static extern void VJoy_Set(int x, int y, int z, int btns);

		public this()
		{
			gApp = this;

			mIRSdk = new IRSdk();
		}

		public int32 GetWindowX(int32 width)
		{
			GetWorkspaceRect(var workspaceX, var workspaceY, var workspaceWidth, var workspaceHeight);
			if (workspaceWidth < 0)
				return 64;
			return (.)(workspaceX + workspaceWidth - width - 24);
		}

		public override void Init()
		{
			base.Init();

			mSmFont = new Font()..Load(scope $"{mInstallDir}/fonts/Montserrat-Medium.ttf", 15);
			mMedFont = new Font()..Load(scope $"{mInstallDir}/fonts/Montserrat-SemiBold.ttf", 16);
			mTinyMonoFont = new Font()..Load("Segoe UI Bold", 12);
			mSmMonoFont = new Font()..Load("Segoe UI Bold", 15);
			mMedMonoFont = new Font()..Load("Segoe UI Bold", 18);
			mLgMonoFont = new Font()..Load("Segoe UI Bold", 22);
			//mMedFont = new Font()..Load("Arial", 30);

			mMapCarImage = Image.LoadFromFile(scope $"{mInstallDir}/images/MapCar.png");
			mMapPointerImage = Image.LoadFromFile(scope $"{mInstallDir}/images/MapPointer.png");
			mChevronImage = Image.LoadFromFile(scope $"{mInstallDir}/images/Chevron.png");

			DarkTheme aTheme = new DarkTheme();
			aTheme.Init();
			ThemeFactory.mDefault = aTheme;

			mInputManager = new InputManager();
			CheckInputDevices();

			mConfigWidget = new .();
			mConfigWindow = new WidgetWindow(null, "iBuddy Config", GetWindowX(320), 660, 320, 240, .QuitOnClose | .Caption | .SysMenu | .Minimize, mConfigWidget);

			mSimInputManager = new SimInputManager();
		}

		public void CheckInputDevices()
		{
			/*Stopwatch sw = scope .();
			sw.Start();
			defer
			{
				sw.Stop();
				Debug.WriteLine($"CheckInputDevices time : {sw.ElapsedMilliseconds}");
			}*/

			void CheckInputDevice(ref InputDevice inputDevice)
			{
				if (inputDevice != null)
				{
					String state = scope .();
					inputDevice.GetState(state);
					if (state.StartsWith("!"))
					{
						using (mMonitor.Enter())
							DeleteAndNullify!(inputDevice);
					}

					//Debug.WriteLine($"State: {state}");
				}
			}

			void CreateInputDevice(ref InputDevice inputDevice, StringView prodName, StringView guid)
			{
				if (inputDevice != null)
					return;
				using (mMonitor.Enter())
				{
					inputDevice = mInputManager.CreateInputDevice(prodName, guid);
					if (inputDevice != null)
					{
						String state = scope .();
						inputDevice.GetState(state);
					}
				}
			}

			CheckInputDevice(ref mWheelbaseInputDevice);
			CheckInputDevice(ref mWheelInputDevice);
			CheckInputDevice(ref mPedalsInputDevice);

			if ((mWheelInputDevice == null) || (mWheelbaseInputDevice == null))
			{
				String devices = scope .();
				mInputManager.CachedEnumerateInputDevices(devices);
				//mInputManager.EnumerateInputDevices(devices);

				String bestProdName = scope .();
				String bestGuid = scope .();

				for (var dev in devices.Split('\n'))
				{
					if (dev.IsEmpty)
						continue;

					var e = dev.Split('\t');
					StringView instName = e.GetNext();
					StringView prodName = e.GetNext();
					StringView guid = e.GetNext();

					bool isBest = false;
					if (prodName.StartsWith("Ascher Racing F64"))
					{
						CreateInputDevice(ref mWheelInputDevice, prodName, guid);
					}
					else if (prodName.StartsWith("GSI Steering Wheel"))
					{
						CreateInputDevice(ref mWheelInputDevice, prodName, guid);
					}
					else if (prodName.StartsWith("Simucube 2"))
					{
						CreateInputDevice(ref mWheelbaseInputDevice, prodName, guid);
					}
					else if (prodName.StartsWith("HE SIM PEDALS"))
					{
						CreateInputDevice(ref mPedalsInputDevice, prodName, guid);
					}
				}
			}
		}

		public override void Shutdown()
		{
			base.Shutdown();

			if (mBoardWindow != null)
				mBoardWindow.Close();
			if (mLapInputWindow != null)
				mLapInputWindow.Close();
		}

		void CheckStartRecording()
		{
			List<Process> processList = scope .();
			Process.GetProcesses(processList);
			defer ClearAndDeleteItems(processList);

			for (var process in processList)
			{
				if (process.ProcessName.Contains("iReplay"))
					return;
			}

			for (var file in Directory.EnumerateFiles(scope $"{mInstallDir}/replay"))
			{
				var fileAge = DateTime.Now - file.GetLastWriteTime();
				var totalDays = fileAge.TotalDays;
				if (totalDays >= 7)
				{
					String filePath = scope .();
					file.GetFilePath(filePath);
					File.Delete(filePath).IgnoreError();
				}
			}

			String filePath = scope $"{DateTime.Now:yyyy_MM_dd__HH_mm}";
			filePath.Insert(0, scope $"{mInstallDir}/replay/");
			filePath.Append(".dat");

			String dir = scope .();
			Path.GetDirectoryPath(filePath, dir);
			Directory.CreateDirectory(dir).IgnoreError();

			mIRSdk.StartRecording(filePath).IgnoreError();

			return;
		}

		public override void Update(bool batchStart)
		{
			base.Update(batchStart);

			mIRSdk.Update();

			mLapInputState = Enum.Parse<LapInputState>(mConfigWidget.mRecordLapCombo.Label).GetValueOrDefault();

			bool wantRecording = (mConfigWidget.mRecordDataCheckbox.Checked) && (mBoard != null);
			if (wantRecording)
			{
				if (!mIRSdk.IsRecordingStream)
					CheckStartRecording();
			}
			else
				mIRSdk.StopRecording();

			if (mIRSdk.IsRunning)
			{
				if (mBoard == null)
				{
					mBoard = new Board();
					BFWindowBase.Flags windowFlags = default;
					windowFlags |= .TopMost;
					//mWindow = new WidgetWindow(null, "iBuddy Relative", 660, 320, 600, 900 /*240*/, windowFlags, mBoard);
					mBoardWindow = new WidgetWindow(null, "iBuddy Relative", GetWindowX(640), 16, 640, 360, windowFlags, mBoard);
					mBoard.SetFocus();
				}
			}
			else
			{
				if (mBoardWindow != null)
				{
					mBoardWindow.Close();
					mBoardWindow = null;
					mBoard = null;
				}

				mLapInputState = .Disabled;
			}

			bool wantLapInputRecording = mLapInputState == .Record;
			if ((mLapInputState == .Disabled) || (mLapInputWidget?.mRecording != wantLapInputRecording))
			{
				if (mLapInputWindow != null)
				{
					mLapInputWindow.Close();
					mLapInputWindow = null;
					mLapInputWidget = null;
				}
			}

			if (mLapInputState != .Disabled)
			{
				if (mLapInputWindow == null)
				{
					mLapInputWidget = new LapInputWidget(wantLapInputRecording);
					BFWindowBase.Flags windowFlags = default;
					windowFlags |= .TopMost;
					mLapInputWindow = new WidgetWindow(null, "iBuddy Input", GetWindowX(616), 400, 616, 240, windowFlags, mLapInputWidget);
				}
			}

			if (mUpdateCnt % 60 == 0)
				CheckInputDevices();

			/*if ((mPedalsInputDevice != null) && (mUpdateCnt % 60 == 0))
			{
				String state = scope .();
				mPedalsInputDevice.GetState(state);
				Debug.WriteLine($"Pedal state: {state}");
			}*/

			mSimInputManager.Update();
		}

		public void Fail(StringView str)
		{
			Windows.MessageBoxA(default, str.ToScopeCStr!(), "IBUDDY ERROR", Windows.MB_ICONHAND | Windows.MB_OK);
		}
	}

	static
	{
		public static IBApp gApp;
	}
}
